/**
 * Route handlers for the query-transcripts Lambda
 */

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';
import OpenAI from 'openai';
import { QueryRequest, RecordingSummary } from './types';
import { getOrCreateUserByClerkId } from './user-service';
import { getTranscriptFromS3, formatForChatGPT } from './transcript-service';
import { hybridSearch, generateQueryEmbedding } from './search-service';

interface HandlerDeps {
  dynamoClient: DynamoDBDocumentClient;
  s3Client: S3Client;
  openai: OpenAI | null;
  dynamoTable: string;
  usersTable: string;
  transcriptsBucket: string;
}

/**
 * List recordings for a user
 */
export async function handleListRecordings(
  event: APIGatewayProxyEventV2,
  deps: HandlerDeps
): Promise<APIGatewayProxyResultV2> {
  const params = event.queryStringParameters || {};
  const userId = params.userId || 'default-user';
  const limit = parseInt(params.limit || '20', 10);
  const from = params.from;
  const to = params.to;

  console.log(`Listing recordings for user: ${userId}, limit: ${limit}`);

  let keyConditionExpression = 'PK = :userId';
  const expressionAttributeValues: Record<string, unknown> = {
    ':userId': userId,
    ':status': 'TRANSCRIBED',
  };

  if (from && to) {
    keyConditionExpression += ' AND SK BETWEEN :from AND :to';
    expressionAttributeValues[':from'] = from;
    expressionAttributeValues[':to'] = to;
  }

  const queryResult = await deps.dynamoClient.send(
    new QueryCommand({
      TableName: deps.dynamoTable,
      KeyConditionExpression: keyConditionExpression,
      FilterExpression: '#status = :status',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: expressionAttributeValues,
      ScanIndexForward: false,
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

    if (item.transcriptS3Key) {
      const transcript = await getTranscriptFromS3(deps.s3Client, deps.transcriptsBucket, item.transcriptS3Key);
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
export async function handleGetTranscript(
  event: APIGatewayProxyEventV2,
  deps: HandlerDeps
): Promise<APIGatewayProxyResultV2> {
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

  const queryResult = await deps.dynamoClient.send(
    new QueryCommand({
      TableName: deps.dynamoTable,
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

  const transcript = await getTranscriptFromS3(deps.s3Client, deps.transcriptsBucket, item.transcriptS3Key);

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
export async function handleUserLookup(
  event: APIGatewayProxyEventV2,
  deps: HandlerDeps
): Promise<APIGatewayProxyResultV2> {
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
    const user = await getOrCreateUserByClerkId(deps.dynamoClient, deps.usersTable, clerkUserId, email);

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
 * Handle query for memories
 */
export async function handleQuery(
  event: APIGatewayProxyEventV2,
  deps: HandlerDeps
): Promise<APIGatewayProxyResultV2> {
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

  let keyConditionExpression = 'PK = :userId';
  const expressionAttributeValues: Record<string, unknown> = {
    ':userId': request.userId,
    ':status': 'TRANSCRIBED',
  };

  if (from && to) {
    keyConditionExpression += ' AND SK BETWEEN :from AND :to';
    expressionAttributeValues[':from'] = from;
    expressionAttributeValues[':to'] = to;
  }

  const queryResult = await deps.dynamoClient.send(
    new QueryCommand({
      TableName: deps.dynamoTable,
      KeyConditionExpression: keyConditionExpression,
      FilterExpression: '#status = :status',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: expressionAttributeValues,
      Limit: 100,
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

  const queryEmbedding = await generateQueryEmbedding(deps.openai, request.query);

  if (queryEmbedding) {
    console.log('Using hybrid search (keywords + semantic)');
  } else {
    console.log('Using keyword search only');
  }

  const allResults: Array<{
    recordingId: string;
    deviceId: string;
    recordingStartedAt: string;
    segmentStart: number;
    segmentEnd: number;
    text: string;
    relevanceScore?: number;
  }> = [];

  for (const item of queryResult.Items) {
    if (!item.transcriptS3Key) continue;

    const transcript = await getTranscriptFromS3(deps.s3Client, deps.transcriptsBucket, item.transcriptS3Key);
    if (!transcript) continue;

    const matches = hybridSearch(transcript, request.query, queryEmbedding, item.startedAt, speakerFilter);
    allResults.push(...matches);
  }

  allResults.sort((a, b) => (b.relevanceScore || 0) - (a.relevanceScore || 0));

  const limitedResults = allResults.slice(0, limit);

  console.log(`Found ${allResults.length} matching segments, returning ${limitedResults.length}`);

  const chatGPTMemories = formatForChatGPT(limitedResults);

  const summary = chatGPTMemories.length > 0
    ? `Found ${chatGPTMemories.length} relevant memories from your past recordings.`
    : 'No relevant memories found for this query.';

  // Return both 'results' (for website) and 'memories' (for ChatGPT plugin)
  return {
    statusCode: 200,
    body: JSON.stringify({
      success: true,
      summary,
      results: chatGPTMemories,  // For website compatibility
      memories: chatGPTMemories,
      rawResults: limitedResults,
      totalMatches: allResults.length,
    }),
  };
}

