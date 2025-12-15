/**
 * Search service
 * Handles keyword, semantic, and hybrid search in transcripts
 */

import OpenAI from 'openai';
import { TranscriptData, QueryResultSegment } from './types';

/**
 * Calculate cosine similarity between two vectors
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (!a || !b || a.length !== b.length) return 0;

  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magnitudeA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magnitudeB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));

  if (magnitudeA === 0 || magnitudeB === 0) return 0;

  return dotProduct / (magnitudeA * magnitudeB);
}

/**
 * Generate embedding for a query using OpenAI
 */
export async function generateQueryEmbedding(
  openai: OpenAI | null,
  query: string
): Promise<number[] | null> {
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

/**
 * Keyword-based search in transcript
 */
export function searchInTranscript(
  transcript: TranscriptData,
  query: string,
  recordingStartedAt: string,
  speakerFilter?: string
): QueryResultSegment[] {
  const results: QueryResultSegment[] = [];
  const keywords = query.toLowerCase().split(/\s+/).filter(k => k.length > 2);

  for (let i = 0; i < transcript.segments.length; i++) {
    const segment = transcript.segments[i];

    if (speakerFilter && segment.speaker !== speakerFilter) {
      continue;
    }

    const segmentText = segment.text.toLowerCase();
    let matchCount = 0;
    let exactPhraseMatch = false;

    if (segmentText.includes(query.toLowerCase())) {
      exactPhraseMatch = true;
      matchCount = keywords.length * 2;
    } else {
      for (const keyword of keywords) {
        if (segmentText.includes(keyword)) {
          matchCount++;
        }
      }
    }

    if (matchCount > 0) {
      const contextSegments = [];
      if (i > 0) contextSegments.push(transcript.segments[i - 1].text);
      contextSegments.push(segment.text);
      if (i < transcript.segments.length - 1) contextSegments.push(transcript.segments[i + 1].text);

      const contextText = contextSegments.join(' ');
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

/**
 * Semantic search using embeddings
 */
export function semanticSearchInTranscript(
  transcript: TranscriptData,
  queryEmbedding: number[],
  recordingStartedAt: string,
  speakerFilter?: string
): QueryResultSegment[] {
  const results: QueryResultSegment[] = [];

  for (let i = 0; i < transcript.segments.length; i++) {
    const segment = transcript.segments[i];

    if (speakerFilter && segment.speaker !== speakerFilter) {
      continue;
    }

    if (!segment.embedding) continue;

    const similarity = cosineSimilarity(queryEmbedding, segment.embedding);

    if (similarity > 0.7) {
      const contextSegments = [];
      if (i > 0) contextSegments.push(transcript.segments[i - 1].text);
      contextSegments.push(segment.text);
      if (i < transcript.segments.length - 1) contextSegments.push(transcript.segments[i + 1].text);

      const contextText = contextSegments.join(' ');
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

/**
 * Hybrid search combining keyword and semantic search
 */
export function hybridSearch(
  transcript: TranscriptData,
  query: string,
  queryEmbedding: number[] | null,
  recordingStartedAt: string,
  speakerFilter?: string
): QueryResultSegment[] {
  const keywordResults = searchInTranscript(transcript, query, recordingStartedAt, speakerFilter);

  if (!queryEmbedding) {
    return keywordResults;
  }

  const semanticResults = semanticSearchInTranscript(transcript, queryEmbedding, recordingStartedAt, speakerFilter);

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
      existing.relevanceScore = (existing.relevanceScore || 0) + (result.relevanceScore || 0) * 0.7;
    } else {
      combinedMap.set(key, {
        ...result,
        relevanceScore: (result.relevanceScore || 0) * 0.7,
      });
    }
  }

  return Array.from(combinedMap.values()).sort((a, b) =>
    (b.relevanceScore || 0) - (a.relevanceScore || 0)
  );
}

