import { auth, currentUser } from '@clerk/nextjs/server';
import { NextRequest, NextResponse } from 'next/server';

// Your AWS API Gateway endpoint for query-transcripts
const QUERY_API_URL = process.env.QUERY_API_URL || 'https://your-api-gateway.execute-api.us-east-1.amazonaws.com';
const QUERY_API_KEY = process.env.QUERY_API_KEY || '';

interface ChatRequest {
  message: string;
  from?: string;
  to?: string;
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

export async function POST(request: NextRequest) {
  try {
    // Get authenticated user
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Get user's email from Clerk
    // This is how you connect Clerk userId to your backend userId
    const user = await currentUser();
    const userEmail = user?.emailAddresses?.[0]?.emailAddress;

    if (!userEmail) {
      return NextResponse.json(
        { error: 'User email not found' },
        { status: 400 }
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

    // Call your query-transcripts Lambda
    // Use email as the userId (or you can use Clerk's userId if you configure your device that way)
    const queryPayload = {
      userId: userEmail, // Using email as userId - change this if you use Clerk userId in your backend
      query: message,
      limit: 10,
      ...(from && { from }),
      ...(to && { to }),
    };

    const response = await fetch(`${QUERY_API_URL}/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': QUERY_API_KEY,
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

