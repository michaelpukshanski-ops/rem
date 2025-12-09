/**
 * REM Ingest Audio Lambda
 * Receives audio uploads from ESP32, stores in S3, creates DynamoDB record
 */

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';
import Busboy from 'busboy';
import { Readable } from 'stream';

const s3Client = new S3Client({});
const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const RAW_AUDIO_BUCKET = process.env.RAW_AUDIO_BUCKET!;
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE!;
const USER_ID = process.env.USER_ID!;
const API_KEY = process.env.API_KEY!;

interface UploadFields {
  deviceId?: string;
  startedAt?: string;
  endedAt?: string;
}

interface UploadFile {
  filename: string;
  mimeType: string;
  data: Buffer;
}

async function parseMultipartFormData(
  event: APIGatewayProxyEventV2
): Promise<{ fields: UploadFields; file: UploadFile | null }> {
  return new Promise((resolve, reject) => {
    const contentType = event.headers['content-type'] || event.headers['Content-Type'];
    
    if (!contentType || !contentType.includes('multipart/form-data')) {
      reject(new Error('Content-Type must be multipart/form-data'));
      return;
    }
    
    const fields: UploadFields = {};
    let file: UploadFile | null = null;
    
    const busboy = Busboy({ headers: { 'content-type': contentType } });
    
    busboy.on('field', (fieldname: string, value: string) => {
      console.log(`Field: ${fieldname} = ${value}`);
      if (fieldname === 'deviceId') fields.deviceId = value;
      if (fieldname === 'startedAt') fields.startedAt = value;
      if (fieldname === 'endedAt') fields.endedAt = value;
    });
    
    busboy.on('file', (fieldname: string, fileStream: Readable, info: any) => {
      console.log(`File: ${fieldname}, filename: ${info.filename}`);
      const chunks: Buffer[] = [];
      fileStream.on('data', (chunk: Buffer) => chunks.push(chunk));
      fileStream.on('end', () => {
        file = {
          filename: info.filename,
          mimeType: info.mimeType,
          data: Buffer.concat(chunks),
        };
        console.log(`File received: ${file.data.length} bytes`);
      });
    });
    
    busboy.on('finish', () => resolve({ fields, file }));
    busboy.on('error', (error: Error) => reject(error));
    
    const body = event.isBase64Encoded
      ? Buffer.from(event.body || '', 'base64')
      : Buffer.from(event.body || '', 'utf-8');
    
    busboy.write(body);
    busboy.end();
  });
}

function generateS3Key(deviceId: string, startedAt: string, endedAt: string): string {
  const date = new Date(startedAt);
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  const startTs = startedAt.replace(/[:.]/g, '-');
  const endTs = endedAt.replace(/[:.]/g, '-');
  return `raw/${deviceId}/${year}/${month}/${day}/${deviceId}_${startTs}_${endTs}.wav`;
}

function validateApiKey(event: APIGatewayProxyEventV2): boolean {
  const apiKey = event.headers['x-api-key'] || event.headers['X-Api-Key'];
  return apiKey === API_KEY;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  console.log('Ingest audio request received');
  
  try {
    if (!validateApiKey(event)) {
      console.error('Invalid API key');
      return {
        statusCode: 401,
        body: JSON.stringify({ success: false, message: 'Unauthorized' }),
      };
    }
    
    const { fields, file } = await parseMultipartFormData(event);
    
    if (!fields.deviceId || !fields.startedAt || !fields.endedAt) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          success: false,
          message: 'Missing required fields: deviceId, startedAt, endedAt',
        }),
      };
    }
    
    if (!file) {
      return {
        statusCode: 400,
        body: JSON.stringify({ success: false, message: 'No file uploaded' }),
      };
    }
    
    const recordingId = uuidv4();
    const s3Key = generateS3Key(fields.deviceId, fields.startedAt, fields.endedAt);
    
    console.log(`Uploading to S3: ${s3Key}`);
    
    await s3Client.send(
      new PutObjectCommand({
        Bucket: RAW_AUDIO_BUCKET,
        Key: s3Key,
        Body: file.data,
        ContentType: file.mimeType || 'audio/wav',
        Metadata: {
          deviceId: fields.deviceId,
          startedAt: fields.startedAt,
          endedAt: fields.endedAt,
          recordingId,
        },
      })
    );
    
    console.log(`S3 upload successful`);
    
    const now = new Date().toISOString();
    await dynamoClient.send(
      new PutCommand({
        TableName: DYNAMODB_TABLE,
        Item: {
          PK: USER_ID,
          SK: recordingId,
          GSI1PK: fields.deviceId,
          GSI1SK: fields.startedAt,
          recordingId,
          deviceId: fields.deviceId,
          s3KeyRaw: s3Key,
          startedAt: fields.startedAt,
          endedAt: fields.endedAt,
          status: 'UPLOADED',
          fileSizeBytes: file.data.length,
          createdAt: now,
          updatedAt: now,
        },
      })
    );
    
    console.log(`DynamoDB record created: ${recordingId}`);
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        recordingId,
        message: 'Audio uploaded successfully',
      }),
    };
  } catch (error) {
    console.error('Error:', error);
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
