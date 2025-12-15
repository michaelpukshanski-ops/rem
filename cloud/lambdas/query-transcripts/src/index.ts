/**
 * REM Query Transcripts Lambda
 * Main entry point - routes requests to appropriate handlers
 */

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';
import OpenAI from 'openai';
import {
  handleListRecordings,
  handleGetTranscript,
  handleUserLookup,
  handleQuery,
} from './handlers';

// Initialize clients
const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const s3Client = new S3Client({});

// Environment variables
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE!;
const USERS_TABLE = process.env.USERS_TABLE!;
const TRANSCRIPTS_BUCKET = process.env.TRANSCRIPTS_BUCKET!;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const API_KEY = process.env.API_KEY!;

// Initialize OpenAI client if API key is available
const openai = OPENAI_API_KEY ? new OpenAI({ apiKey: OPENAI_API_KEY }) : null;

// Shared dependencies for handlers
const deps = {
  dynamoClient,
  s3Client,
  openai,
  dynamoTable: DYNAMODB_TABLE,
  usersTable: USERS_TABLE,
  transcriptsBucket: TRANSCRIPTS_BUCKET,
};

/**
 * Validate API key from request headers
 */
function validateApiKey(event: APIGatewayProxyEventV2): boolean {
  const apiKey = event.headers['x-api-key'] || event.headers['X-Api-Key'];
  return apiKey === API_KEY;
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
      return await handleListRecordings(event, deps);
    }

    if (routeKey.startsWith('GET /transcript/') || path.startsWith('/transcript/')) {
      return await handleGetTranscript(event, deps);
    }

    if (routeKey === 'POST /user' || path === '/user') {
      return await handleUserLookup(event, deps);
    }

    // Default: POST /query
    return await handleQuery(event, deps);
  } catch (error) {
    console.error('Error processing request:', error);
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
