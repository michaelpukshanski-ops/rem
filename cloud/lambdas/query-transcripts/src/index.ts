/**
 * REM Query Transcripts Lambda
 * Searches transcripts by keyword and time range for ChatGPT integration
 * Now with semantic search using OpenAI embeddings!
 */

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, PutCommand, GetCommand } from '@aws-sdk/lib-dynamodb';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import OpenAI from 'openai';
import { v4 as uuidv4 } from 'uuid';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const s3Client = new S3Client({});

const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE!;
const USERS_TABLE = process.env.USERS_TABLE!;
const TRANSCRIPTS_BUCKET = process.env.TRANSCRIPTS_BUCKET!;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const API_KEY = process.env.API_KEY!;

// Initialize OpenAI client if API key is available
const openai = OPENAI_API_KEY ? new OpenAI({ apiKey: OPENAI_API_KEY }) : null;

// ============================================================================
// User Management Types and Functions
// ============================================================================

interface User {
  userId: string;
  clerkUserId: string;
  email: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * Get user by Clerk user ID, or create if doesn't exist
 */
async function getOrCreateUserByClerkId(clerkUserId: string, email: string): Promise<User> {
  // First, try to find existing user by clerkUserId
  const queryResult = await dynamoClient.send(
    new QueryCommand({
      TableName: USERS_TABLE,
      IndexName: 'ClerkUserIdIndex',
      KeyConditionExpression: 'clerkUserId = :clerkUserId',
      ExpressionAttributeValues: {
        ':clerkUserId': clerkUserId,
      },
      Limit: 1,
    })
  );

  if (queryResult.Items && queryResult.Items.length > 0) {
    return queryResult.Items[0] as User;
  }

  // User doesn't exist, create new one
  const now = new Date().toISOString();
  const newUser: User = {
    userId: uuidv4(),
    clerkUserId,
    email,
    createdAt: now,
    updatedAt: now,
  };

  await dynamoClient.send(
    new PutCommand({
      TableName: USERS_TABLE,
      Item: newUser,
      ConditionExpression: 'attribute_not_exists(userId)',
    })
  );

  console.log(`Created new user: ${newUser.userId} for clerkUserId: ${clerkUserId}`);
  return newUser;
}

/**
 * Get user by internal userId
 */
async function getUserById(userId: string): Promise<User | null> {
  const result = await dynamoClient.send(
    new GetCommand({
      TableName: USERS_TABLE,
      Key: { userId },
    })
  );

  return result.Item as User | null;
}

/**
 * Validate API key from request headers
 */
function validateApiKey(event: APIGatewayProxyEventV2): boolean {
  const apiKey = event.headers['x-api-key'] || event.headers['X-Api-Key'];
  return apiKey === API_KEY;
}

interface QueryRequest {
  userId: string;
  query: string;
  from?: string;
  to?: string;
  limit?: number;
  speaker?: string;  // Filter by specific speaker
}

interface RecordingSummary {
  recordingId: string;
  deviceId: string;
  startedAt: string;
  durationSeconds: number;
  status: string;
  summary?: string;
  topics?: string[];
  speakers?: string[];
  speakerCount?: number;
  language?: string;
  wordCount?: number;
}

interface TranscriptSegment {
  id: number;
  start: number;
  end: number;
  text: string;
  embedding?: number[];
  speaker?: string;
}

interface TranscriptData {
  recordingId: string;
  userId: string;
  deviceId: string;
  language: string;
  segments: TranscriptSegment[];
  fullText: string;
  durationSeconds: number;
  transcribedAt: string;
  whisperModel: string;
  embedding?: number[];
  summary?: string;
  topics?: string[];
  speakers?: string[];
  speakerCount?: number;
}

interface QueryResultSegment {
  recordingId: string;
  deviceId: string;
  recordingStartedAt: string;
  segmentStart: number;
  segmentEnd: number;
  text: string;
  relevanceScore?: number;
}

interface ChatGPTMemory {
  timestamp: string;
  text: string;
  context: string;
  relevance: number;
}

async function getTranscriptFromS3(s3Key: string): Promise<TranscriptData | null> {
  try {
    const response = await s3Client.send(
      new GetObjectCommand({
        Bucket: TRANSCRIPTS_BUCKET,
        Key: s3Key,
      })
    );
    
    const bodyString = await response.Body?.transformToString();
    if (!bodyString) return null;
    
    return JSON.parse(bodyString) as TranscriptData;
  } catch (error) {
    console.error(`Error fetching transcript from S3: ${s3Key}`, error);
    return null;
  }
}

function searchInTranscript(
  transcript: TranscriptData,
  query: string,
  recordingStartedAt: string,
  speakerFilter?: string
): QueryResultSegment[] {
  const results: QueryResultSegment[] = [];
  const keywords = query.toLowerCase().split(/\s+/).filter(k => k.length > 2);

  for (let i = 0; i < transcript.segments.length; i++) {
    const segment = transcript.segments[i];

    // Filter by speaker if specified
    if (speakerFilter && segment.speaker !== speakerFilter) {
      continue;
    }

    const segmentText = segment.text.toLowerCase();
    let matchCount = 0;
    let exactPhraseMatch = false;

    // Check for exact phrase match
    if (segmentText.includes(query.toLowerCase())) {
      exactPhraseMatch = true;
      matchCount = keywords.length * 2; // Boost exact matches
    } else {
      // Check for keyword matches
      for (const keyword of keywords) {
        if (segmentText.includes(keyword)) {
          matchCount++;
        }
      }
    }

    if (matchCount > 0) {
      // Get context: include previous and next segments for better understanding
      const contextSegments = [];
      if (i > 0) contextSegments.push(transcript.segments[i - 1].text);
      contextSegments.push(segment.text);
      if (i < transcript.segments.length - 1) contextSegments.push(transcript.segments[i + 1].text);

      const contextText = contextSegments.join(' ');

      // Add speaker info to context if available
      const contextWithSpeaker = segment.speaker
        ? `[${segment.speaker}] ${contextText}`
        : contextText;

      results.push({
        recordingId: transcript.recordingId,
        deviceId: transcript.deviceId,
        recordingStartedAt,
        segmentStart: segment.start,
        segmentEnd: segment.end,
        text: contextWithSpeaker,
        relevanceScore: exactPhraseMatch ? 1.0 : matchCount / keywords.length,
      });
    }
  }

  return results;
}

function formatForChatGPT(results: QueryResultSegment[]): ChatGPTMemory[] {
  return results.map(result => {
    const date = new Date(result.recordingStartedAt);
    const timeOffset = Math.floor(result.segmentStart);
    const timestamp = new Date(date.getTime() + timeOffset * 1000);

    return {
      timestamp: timestamp.toISOString(),
      text: result.text,
      context: `Recorded on ${date.toLocaleDateString()} at ${date.toLocaleTimeString()}`,
      relevance: Math.round((result.relevanceScore || 0) * 100) / 100,
    };
  });
}

async function generateQueryEmbedding(query: string): Promise<number[] | null> {
  if (!openai) {
    console.log('OpenAI not configured, skipping embedding generation');
    return null;
  }

  try {
    console.log(`Generating embedding for query: "${query}"`);
    const response = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: query,
    });
    return response.data[0].embedding;
  } catch (error) {
    console.error('Failed to generate query embedding:', error);
    return null;
  }
}

function cosineSimilarity(a: number[], b: number[]): number {
  if (!a || !b || a.length !== b.length) return 0;

  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magnitudeA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magnitudeB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));

  if (magnitudeA === 0 || magnitudeB === 0) return 0;

  return dotProduct / (magnitudeA * magnitudeB);
}

function semanticSearchInTranscript(
  transcript: TranscriptData,
  queryEmbedding: number[],
  recordingStartedAt: string,
  speakerFilter?: string
): QueryResultSegment[] {
  const results: QueryResultSegment[] = [];

  // Search in segments
  for (let i = 0; i < transcript.segments.length; i++) {
    const segment = transcript.segments[i];

    // Filter by speaker if specified
    if (speakerFilter && segment.speaker !== speakerFilter) {
      continue;
    }

    if (!segment.embedding) continue;

    const similarity = cosineSimilarity(queryEmbedding, segment.embedding);

    // Only include segments with similarity > 0.7 (highly relevant)
    if (similarity > 0.7) {
      // Get context: include previous and next segments
      const contextSegments = [];
      if (i > 0) contextSegments.push(transcript.segments[i - 1].text);
      contextSegments.push(segment.text);
      if (i < transcript.segments.length - 1) contextSegments.push(transcript.segments[i + 1].text);

      const contextText = contextSegments.join(' ');

      // Add speaker info to context if available
      const contextWithSpeaker = segment.speaker
        ? `[${segment.speaker}] ${contextText}`
        : contextText;

      results.push({
        recordingId: transcript.recordingId,
        deviceId: transcript.deviceId,
        recordingStartedAt,
        segmentStart: segment.start,
        segmentEnd: segment.end,
        text: contextWithSpeaker,
        relevanceScore: similarity,
      });
    }
  }

  return results;
}

function hybridSearch(
  transcript: TranscriptData,
  query: string,
  queryEmbedding: number[] | null,
  recordingStartedAt: string,
  speakerFilter?: string
): QueryResultSegment[] {
  // Get keyword search results
  const keywordResults = searchInTranscript(transcript, query, recordingStartedAt, speakerFilter);

  // If no embedding, return keyword results only
  if (!queryEmbedding) {
    return keywordResults;
  }

  // Get semantic search results
  const semanticResults = semanticSearchInTranscript(transcript, queryEmbedding, recordingStartedAt, speakerFilter);

  // Combine results with hybrid scoring
  const combinedMap = new Map<string, QueryResultSegment>();

  // Add keyword results with 30% weight
  for (const result of keywordResults) {
    const key = `${result.recordingId}-${result.segmentStart}`;
    combinedMap.set(key, {
      ...result,
      relevanceScore: (result.relevanceScore || 0) * 0.3,
    });
  }

  // Add or merge semantic results with 70% weight
  for (const result of semanticResults) {
    const key = `${result.recordingId}-${result.segmentStart}`;
    const existing = combinedMap.get(key);

    if (existing) {
      // Combine scores
      existing.relevanceScore = (existing.relevanceScore || 0) + (result.relevanceScore || 0) * 0.7;
    } else {
      combinedMap.set(key, {
        ...result,
        relevanceScore: (result.relevanceScore || 0) * 0.7,
      });
    }
  }

  // Convert to array and sort by relevance
  return Array.from(combinedMap.values()).sort((a, b) =>
    (b.relevanceScore || 0) - (a.relevanceScore || 0)
  );
}

/**
 * List recordings for a user
 */
async function handleListRecordings(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const params = event.queryStringParameters || {};
  const userId = params.userId || 'default-user';
  const limit = parseInt(params.limit || '20', 10);
  const from = params.from;
  const to = params.to;

  console.log(`Listing recordings for user: ${userId}, limit: ${limit}`);

  let keyConditionExpression = 'PK = :userId';
  const expressionAttributeValues: any = {
    ':userId': userId,
    ':status': 'TRANSCRIBED',
  };

  if (from && to) {
    keyConditionExpression += ' AND SK BETWEEN :from AND :to';
    expressionAttributeValues[':from'] = from;
    expressionAttributeValues[':to'] = to;
  }

  const queryResult = await dynamoClient.send(
    new QueryCommand({
      TableName: DYNAMODB_TABLE,
      KeyConditionExpression: keyConditionExpression,
      FilterExpression: '#status = :status',
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: expressionAttributeValues,
      ScanIndexForward: false, // Most recent first
      Limit: limit,
    })
  );

  const recordings: RecordingSummary[] = [];

  for (const item of queryResult.Items || []) {
    const recording: RecordingSummary = {
      recordingId: item.recordingId,
      deviceId: item.deviceId,
      startedAt: item.startedAt,
      durationSeconds: item.durationSeconds || 0,
      status: item.status,
    };

    // If there's a transcript, get summary info from it
    if (item.transcriptS3Key) {
      const transcript = await getTranscriptFromS3(item.transcriptS3Key);
      if (transcript) {
        recording.summary = transcript.summary;
        recording.topics = transcript.topics;
        recording.speakers = transcript.speakers;
        recording.speakerCount = transcript.speakerCount;
        recording.language = transcript.language;
        recording.wordCount = transcript.fullText?.split(/\s+/).length || 0;
      }
    }

    recordings.push(recording);
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      success: true,
      recordings,
      count: recordings.length,
      message: recordings.length > 0
        ? `Found ${recordings.length} recordings.`
        : 'No recordings found.',
    }),
  };
}

/**
 * Get full transcript for a specific recording
 */
async function handleGetTranscript(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const params = event.queryStringParameters || {};
  const userId = params.userId || 'default-user';
  const recordingId = event.pathParameters?.recordingId;

  if (!recordingId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ success: false, message: 'recordingId is required' }),
    };
  }

  console.log(`Getting transcript for recording: ${recordingId}, user: ${userId}`);

  // Query DynamoDB to find the recording
  const queryResult = await dynamoClient.send(
    new QueryCommand({
      TableName: DYNAMODB_TABLE,
      KeyConditionExpression: 'PK = :userId',
      FilterExpression: 'recordingId = :recordingId',
      ExpressionAttributeValues: {
        ':userId': userId,
        ':recordingId': recordingId,
      },
      Limit: 1,
    })
  );

  if (!queryResult.Items || queryResult.Items.length === 0) {
    return {
      statusCode: 404,
      body: JSON.stringify({ success: false, message: 'Recording not found' }),
    };
  }

  const item = queryResult.Items[0];

  if (!item.transcriptS3Key) {
    return {
      statusCode: 404,
      body: JSON.stringify({
        success: false,
        message: 'Transcript not available',
        status: item.status,
      }),
    };
  }

  const transcript = await getTranscriptFromS3(item.transcriptS3Key);

  if (!transcript) {
    return {
      statusCode: 500,
      body: JSON.stringify({ success: false, message: 'Failed to retrieve transcript' }),
    };
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      success: true,
      recordingId: transcript.recordingId,
      deviceId: transcript.deviceId,
      startedAt: item.startedAt,
      durationSeconds: transcript.durationSeconds,
      language: transcript.language,
      fullText: transcript.fullText,
      summary: transcript.summary,
      topics: transcript.topics,
      speakers: transcript.speakers,
      speakerCount: transcript.speakerCount,
      segments: transcript.segments.map(s => ({
        start: s.start,
        end: s.end,
        text: s.text,
        speaker: s.speaker,
      })),
    }),
  };
}

/**
 * Handle user lookup/creation by Clerk user ID
 */
async function handleUserLookup(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  if (!event.body) {
    return {
      statusCode: 400,
      body: JSON.stringify({ success: false, message: 'Request body required' }),
    };
  }

  const { clerkUserId, email } = JSON.parse(event.body);

  if (!clerkUserId || !email) {
    return {
      statusCode: 400,
      body: JSON.stringify({
        success: false,
        message: 'clerkUserId and email are required',
      }),
    };
  }

  try {
    const user = await getOrCreateUserByClerkId(clerkUserId, email);

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        user: {
          userId: user.userId,
          email: user.email,
          createdAt: user.createdAt,
        },
      }),
    };
  } catch (error) {
    console.error('Error in user lookup:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ success: false, message: 'Failed to lookup user' }),
    };
  }
}

/**
 * Main handler - routes to appropriate function based on path
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const routeKey = event.routeKey || '';
  const path = event.rawPath || '';

  console.log(`Request: ${routeKey}, path: ${path}`);

  try {
    // Validate API key
    if (!validateApiKey(event)) {
      console.error('Invalid API key');
      return {
        statusCode: 401,
        body: JSON.stringify({ success: false, message: 'Unauthorized' }),
      };
    }

    // Route based on path
    if (routeKey === 'GET /recordings' || path === '/recordings') {
      return await handleListRecordings(event);
    }

    if (routeKey.startsWith('GET /transcript/') || path.startsWith('/transcript/')) {
      return await handleGetTranscript(event);
    }

    // User lookup endpoint - POST /user
    if (routeKey === 'POST /user' || path === '/user') {
      return await handleUserLookup(event);
    }

    // Default: POST /query (original behavior)
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ success: false, message: 'Request body required' }),
      };
    }

    const request: QueryRequest = JSON.parse(event.body);

    if (!request.userId || !request.query) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          success: false,
          message: 'userId and query are required',
        }),
      };
    }

    const limit = request.limit || 10;
    const from = request.from;
    const to = request.to;
    const speakerFilter = request.speaker;

    console.log(`Querying for user: ${request.userId}, query: "${request.query}"${speakerFilter ? `, speaker: ${speakerFilter}` : ''}`);
    
    // Query DynamoDB for transcribed recordings
    let keyConditionExpression = 'PK = :userId';
    const expressionAttributeValues: any = {
      ':userId': request.userId,
      ':status': 'TRANSCRIBED',
    };
    
    // Add time range filter if provided
    if (from && to) {
      keyConditionExpression += ' AND SK BETWEEN :from AND :to';
      expressionAttributeValues[':from'] = from;
      expressionAttributeValues[':to'] = to;
    }
    
    const queryResult = await dynamoClient.send(
      new QueryCommand({
        TableName: DYNAMODB_TABLE,
        KeyConditionExpression: keyConditionExpression,
        FilterExpression: '#status = :status',
        ExpressionAttributeNames: {
          '#status': 'status',
        },
        ExpressionAttributeValues: expressionAttributeValues,
        Limit: 100, // Get up to 100 recordings to search
      })
    );
    
    if (!queryResult.Items || queryResult.Items.length === 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          success: true,
          results: [],
          totalMatches: 0,
          message: 'No transcribed recordings found',
        }),
      };
    }
    
    console.log(`Found ${queryResult.Items.length} transcribed recordings`);

    // Generate query embedding for semantic search
    const queryEmbedding = await generateQueryEmbedding(request.query);

    if (queryEmbedding) {
      console.log('Using hybrid search (keywords + semantic)');
    } else {
      console.log('Using keyword search only');
    }

    // Search through transcripts
    const allResults: QueryResultSegment[] = [];

    for (const item of queryResult.Items) {
      if (!item.transcriptS3Key) continue;

      const transcript = await getTranscriptFromS3(item.transcriptS3Key);
      if (!transcript) continue;

      // Use hybrid search if embedding is available, otherwise keyword search
      const matches = hybridSearch(transcript, request.query, queryEmbedding, item.startedAt, speakerFilter);
      allResults.push(...matches);
    }

    // Sort by relevance score (already sorted by hybridSearch, but ensure consistency)
    allResults.sort((a, b) => (b.relevanceScore || 0) - (a.relevanceScore || 0));

    // Limit results
    const limitedResults = allResults.slice(0, limit);

    console.log(`Found ${allResults.length} matching segments, returning ${limitedResults.length}`);

    // Format for ChatGPT
    const chatGPTMemories = formatForChatGPT(limitedResults);

    // Create a summary for ChatGPT
    const summary = chatGPTMemories.length > 0
      ? `Found ${chatGPTMemories.length} relevant memories from your past recordings.`
      : 'No relevant memories found for this query.';

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        summary,
        memories: chatGPTMemories,
        rawResults: limitedResults, // Keep original format for backward compatibility
        totalMatches: allResults.length,
      }),
    };
  } catch (error) {
    console.error('Error querying transcripts:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        message: 'Internal server error',
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
}
