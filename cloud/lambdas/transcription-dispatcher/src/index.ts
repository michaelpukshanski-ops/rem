/**
 * REM Transcription Dispatcher Lambda
 * Triggered by S3 ObjectCreated events, enqueues transcription jobs to SQS
 */

import { S3Event } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const sqsClient = new SQSClient({});

const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE!;
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL!;
const USER_ID = process.env.USER_ID!;

async function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function findRecordingWithRetry(deviceId: string, s3Key: string, maxRetries = 3): Promise<any> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    const queryResult = await dynamoClient.send(
      new QueryCommand({
        TableName: DYNAMODB_TABLE,
        IndexName: 'DeviceTimeIndex',
        KeyConditionExpression: 'GSI1PK = :deviceId',
        FilterExpression: 's3KeyRaw = :s3Key',
        ExpressionAttributeValues: {
          ':deviceId': deviceId,
          ':s3Key': s3Key,
        },
        Limit: 1,
      })
    );

    if (queryResult.Items && queryResult.Items.length > 0) {
      return queryResult.Items[0];
    }

    if (attempt < maxRetries) {
      const delayMs = Math.pow(2, attempt) * 100; // 200ms, 400ms, 800ms
      console.log(`Record not found, retrying in ${delayMs}ms (attempt ${attempt}/${maxRetries})`);
      await sleep(delayMs);
    }
  }

  return null;
}

export async function handler(event: S3Event): Promise<void> {
  console.log(`Processing ${event.Records.length} S3 events`);
  
  for (const record of event.Records) {
    try {
      const bucket = record.s3.bucket.name;
      const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
      
      console.log(`Processing S3 object: ${bucket}/${key}`);
      
      // Extract metadata from S3 key
      // Format: raw/{deviceId}/{year}/{month}/{day}/{deviceId}_{startedAt}_{endedAt}.wav
      const keyParts = key.split('/');
      if (keyParts.length < 5 || keyParts[0] !== 'raw') {
        console.log(`Skipping non-raw audio file: ${key}`);
        continue;
      }
      
      const deviceId = keyParts[1];

      // Query DynamoDB to find the recording by s3KeyRaw (with retry for race conditions)
      const recording = await findRecordingWithRetry(deviceId, key);

      if (!recording) {
        console.error(`No DynamoDB record found for S3 key after retries: ${key}`);
        continue;
      }

      const recordingId = recording.recordingId;
      
      console.log(`Found recording: ${recordingId}`);
      
      // Update status to TRANSCRIBING
      await dynamoClient.send(
        new UpdateCommand({
          TableName: DYNAMODB_TABLE,
          Key: {
            PK: USER_ID,
            SK: recordingId,
          },
          UpdateExpression: 'SET #status = :status, updatedAt = :now',
          ExpressionAttributeNames: {
            '#status': 'status',
          },
          ExpressionAttributeValues: {
            ':status': 'TRANSCRIBING',
            ':now': new Date().toISOString(),
          },
        })
      );
      
      // Send message to SQS
      const message = {
        recordingId,
        bucket,
        key,
        userId: USER_ID,
        deviceId: recording.deviceId,
        startedAt: recording.startedAt,
        endedAt: recording.endedAt,
      };
      
      await sqsClient.send(
        new SendMessageCommand({
          QueueUrl: SQS_QUEUE_URL,
          MessageBody: JSON.stringify(message),
          MessageAttributes: {
            recordingId: {
              DataType: 'String',
              StringValue: recordingId,
            },
            deviceId: {
              DataType: 'String',
              StringValue: deviceId,
            },
          },
        })
      );
      
      console.log(`Transcription job enqueued for recording: ${recordingId}`);
    } catch (error) {
      console.error('Error processing S3 event:', error);
      // Don't throw - process other records
    }
  }
}
