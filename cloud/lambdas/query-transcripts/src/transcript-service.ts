/**
 * Transcript service
 * Handles fetching transcripts from S3 and formatting results
 */

import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { TranscriptData, QueryResultSegment, ChatGPTMemory } from './types';

/**
 * Fetch transcript from S3
 */
export async function getTranscriptFromS3(
  s3Client: S3Client,
  bucket: string,
  s3Key: string
): Promise<TranscriptData | null> {
  try {
    const response = await s3Client.send(
      new GetObjectCommand({
        Bucket: bucket,
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

/**
 * Format search results for ChatGPT consumption
 */
export function formatForChatGPT(results: QueryResultSegment[]): ChatGPTMemory[] {
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

