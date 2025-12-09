/**
 * REM Query Transcripts Lambda
 * Searches transcripts by keyword and time range for ChatGPT integration
 */

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const s3Client = new S3Client({});

const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE!;
const TRANSCRIPTS_BUCKET = process.env.TRANSCRIPTS_BUCKET!;

interface QueryRequest {
  userId: string;
  query: string;
  from?: string;
  to?: string;
  limit?: number;
}

interface TranscriptSegment {
  id: number;
  start: number;
  end: number;
  text: string;
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
  recordingStartedAt: string
): QueryResultSegment[] {
  const results: QueryResultSegment[] = [];
  const keywords = query.toLowerCase().split(/\s+/).filter(k => k.length > 2);
  
  for (const segment of transcript.segments) {
    const segmentText = segment.text.toLowerCase();
    let matchCount = 0;
    
    for (const keyword of keywords) {
      if (segmentText.includes(keyword)) {
        matchCount++;
      }
    }
    
    if (matchCount > 0) {
      results.push({
        recordingId: transcript.recordingId,
        deviceId: transcript.deviceId,
        recordingStartedAt,
        segmentStart: segment.start,
        segmentEnd: segment.end,
        text: segment.text,
        relevanceScore: matchCount / keywords.length,
      });
    }
  }
  
  return results;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  console.log('Query transcripts request received');
  
  try {
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
    
    console.log(`Querying for user: ${request.userId}, query: "${request.query}"`);
    
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
    
    // Search through transcripts
    const allResults: QueryResultSegment[] = [];
    
    for (const item of queryResult.Items) {
      if (!item.transcriptS3Key) continue;
      
      const transcript = await getTranscriptFromS3(item.transcriptS3Key);
      if (!transcript) continue;
      
      const matches = searchInTranscript(transcript, request.query, item.startedAt);
      allResults.push(...matches);
    }
    
    // Sort by relevance score
    allResults.sort((a, b) => (b.relevanceScore || 0) - (a.relevanceScore || 0));
    
    // Limit results
    const limitedResults = allResults.slice(0, limit);
    
    console.log(`Found ${allResults.length} matching segments, returning ${limitedResults.length}`);
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        results: limitedResults,
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
