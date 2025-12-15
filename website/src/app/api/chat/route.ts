import { auth, currentUser } from '@clerk/nextjs/server';
import { NextRequest, NextResponse } from 'next/server';

// Your AWS API Gateway endpoint
const API_BASE_URL = process.env.QUERY_API_URL || 'https://your-api-gateway.execute-api.us-east-1.amazonaws.com';
const API_KEY = process.env.QUERY_API_KEY || '';

interface ChatRequest {
  message: string;
  from?: string;
  to?: string;
}

interface UserLookupResponse {
  success: boolean;
  user?: {
    userId: string;
    email: string;
    createdAt: string;
  };
  message?: string;
}

interface QueryResponse {
  success: boolean;
  results?: Array<{
    text: string;
    timestamp: string;
    speaker?: string;
    recordingId: string;
  }>;
  message?: string;
}

/**
 * Look up or create internal userId from Clerk credentials
 */
async function getInternalUserId(clerkUserId: string, email: string): Promise<string | null> {
  try {
    const response = await fetch(`${API_BASE_URL}/user`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY,
      },
      body: JSON.stringify({ clerkUserId, email }),
    });

    if (!response.ok) {
      console.error('User lookup failed:', response.status);
      return null;
    }

    const data: UserLookupResponse = await response.json();
    return data.user?.userId || null;
  } catch (error) {
    console.error('User lookup error:', error);
    return null;
  }
}

export async function POST(request: NextRequest) {
  try {
    // Get authenticated user from Clerk
    const { userId: clerkUserId } = await auth();
    if (!clerkUserId) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Get user's email from Clerk
    const user = await currentUser();
    const userEmail = user?.emailAddresses?.[0]?.emailAddress;

    if (!userEmail) {
      return NextResponse.json(
        { error: 'User email not found' },
        { status: 400 }
      );
    }

    // Look up internal userId from Clerk credentials
    const internalUserId = await getInternalUserId(clerkUserId, userEmail);

    if (!internalUserId) {
      return NextResponse.json(
        { error: 'Failed to resolve user' },
        { status: 500 }
      );
    }

    // Parse request body
    const body: ChatRequest = await request.json();
    const { message, from, to } = body;

    if (!message) {
      return NextResponse.json(
        { error: 'Message is required' },
        { status: 400 }
      );
    }

    // Call query-transcripts Lambda with internal userId
    const queryPayload = {
      userId: internalUserId,
      query: message,
      limit: 10,
      ...(from && { from }),
      ...(to && { to }),
    };

    const response = await fetch(`${API_BASE_URL}/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY,
      },
      body: JSON.stringify(queryPayload),
    });

    if (!response.ok) {
      console.error('Query API error:', response.status, await response.text());
      return NextResponse.json(
        { error: 'Failed to query memories' },
        { status: 500 }
      );
    }

    const data: QueryResponse = await response.json();

    // Format response for chat UI
    if (data.success && data.results && data.results.length > 0) {
      const formattedResults = data.results.map((r) => ({
        text: r.text,
        timestamp: r.timestamp,
        speaker: r.speaker,
        recordingId: r.recordingId,
      }));

      return NextResponse.json({
        success: true,
        message: `Found ${data.results.length} relevant memories:`,
        results: formattedResults,
      });
    }

    return NextResponse.json({
      success: true,
      message: 'No memories found matching your query.',
      results: [],
    });
  } catch (error) {
    console.error('Chat API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

