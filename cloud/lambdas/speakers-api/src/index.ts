/**
 * REM Speakers API Lambda
 * 
 * Manages speaker profiles for voice identification.
 * 
 * Endpoints:
 * - GET /speakers - List all speakers for a user
 * - GET /speakers/{speakerId} - Get a specific speaker
 * - PUT /speakers/{speakerId} - Update speaker (rename)
 * - DELETE /speakers/{speakerId} - Delete a speaker profile
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { 
  DynamoDBDocumentClient, 
  QueryCommand, 
  GetCommand, 
  UpdateCommand, 
  DeleteCommand 
} from '@aws-sdk/lib-dynamodb';

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

const SPEAKERS_TABLE = process.env.SPEAKERS_TABLE || 'rem-speakers-dev';
const USERS_TABLE = process.env.USERS_TABLE || 'rem-users-dev';

interface Speaker {
  userId: string;
  speakerId: string;
  name: string;
  sampleCount: number;
  createdAt: string;
  updatedAt: string;
}

// Helper to create response
function response(statusCode: number, body: object): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization,x-clerk-user-id',
      'Access-Control-Allow-Methods': 'GET,PUT,DELETE,OPTIONS'
    },
    body: JSON.stringify(body)
  };
}

// Get internal userId from Clerk user ID
async function getUserId(clerkUserId: string): Promise<string | null> {
  try {
    const result = await docClient.send(new QueryCommand({
      TableName: USERS_TABLE,
      IndexName: 'clerkUserId-index',
      KeyConditionExpression: 'clerkUserId = :cid',
      ExpressionAttributeValues: { ':cid': clerkUserId }
    }));
    
    if (result.Items && result.Items.length > 0) {
      return result.Items[0].PK as string;
    }
    return null;
  } catch (error) {
    console.error('Error looking up user:', error);
    return null;
  }
}

// List all speakers for a user
async function listSpeakers(userId: string): Promise<Speaker[]> {
  const result = await docClient.send(new QueryCommand({
    TableName: SPEAKERS_TABLE,
    KeyConditionExpression: 'userId = :uid',
    ExpressionAttributeValues: { ':uid': userId },
    ProjectionExpression: 'userId, speakerId, #name, sampleCount, createdAt, updatedAt',
    ExpressionAttributeNames: { '#name': 'name' }
  }));
  
  return (result.Items || []) as Speaker[];
}

// Get a specific speaker
async function getSpeaker(userId: string, speakerId: string): Promise<Speaker | null> {
  const result = await docClient.send(new GetCommand({
    TableName: SPEAKERS_TABLE,
    Key: { userId, speakerId },
    ProjectionExpression: 'userId, speakerId, #name, sampleCount, createdAt, updatedAt',
    ExpressionAttributeNames: { '#name': 'name' }
  }));
  
  return result.Item as Speaker | null;
}

// Update speaker name
async function updateSpeaker(userId: string, speakerId: string, name: string): Promise<Speaker | null> {
  const result = await docClient.send(new UpdateCommand({
    TableName: SPEAKERS_TABLE,
    Key: { userId, speakerId },
    UpdateExpression: 'SET #name = :name, updatedAt = :now',
    ExpressionAttributeNames: { '#name': 'name' },
    ExpressionAttributeValues: {
      ':name': name,
      ':now': new Date().toISOString()
    },
    ReturnValues: 'ALL_NEW',
    ConditionExpression: 'attribute_exists(userId)'
  }));
  
  return result.Attributes as Speaker | null;
}

// Delete a speaker
async function deleteSpeaker(userId: string, speakerId: string): Promise<boolean> {
  await docClient.send(new DeleteCommand({
    TableName: SPEAKERS_TABLE,
    Key: { userId, speakerId },
    ConditionExpression: 'attribute_exists(userId)'
  }));
  return true;
}

// Main handler
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Event:', JSON.stringify(event, null, 2));
  
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return response(200, {});
  }
  
  // Get Clerk user ID from header
  const clerkUserId = event.headers['x-clerk-user-id'] || event.headers['X-Clerk-User-Id'];
  if (!clerkUserId) {
    return response(401, { error: 'Missing x-clerk-user-id header' });
  }
  
  // Look up internal user ID
  const userId = await getUserId(clerkUserId);
  if (!userId) {
    return response(404, { error: 'User not found' });
  }
  
  const path = event.path;
  const method = event.httpMethod;
  const speakerId = event.pathParameters?.speakerId;
  
  try {
    // GET /speakers - List all speakers
    if (method === 'GET' && path === '/speakers') {
      const speakers = await listSpeakers(userId);
      return response(200, { speakers });
    }
    
    // GET /speakers/{speakerId} - Get specific speaker
    if (method === 'GET' && speakerId) {
      const speaker = await getSpeaker(userId, speakerId);
      if (!speaker) {
        return response(404, { error: 'Speaker not found' });
      }
      return response(200, { speaker });
    }
    
    // PUT /speakers/{speakerId} - Update speaker
    if (method === 'PUT' && speakerId) {
      const body = JSON.parse(event.body || '{}');
      if (!body.name) {
        return response(400, { error: 'Missing name in request body' });
      }
      
      const speaker = await updateSpeaker(userId, speakerId, body.name);
      if (!speaker) {
        return response(404, { error: 'Speaker not found' });
      }
      return response(200, { speaker });
    }
    
    // DELETE /speakers/{speakerId} - Delete speaker
    if (method === 'DELETE' && speakerId) {
      await deleteSpeaker(userId, speakerId);
      return response(200, { message: 'Speaker deleted' });
    }
    
    return response(404, { error: 'Not found' });
  } catch (error) {
    console.error('Error:', error);
    return response(500, { error: 'Internal server error' });
  }
}

