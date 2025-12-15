/**
 * Type definitions for REM Query Transcripts Lambda
 */

// ============================================================================
// User Types
// ============================================================================

export interface User {
  userId: string;
  clerkUserId: string;
  email: string;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// Request/Response Types
// ============================================================================

export interface QueryRequest {
  userId: string;
  query: string;
  from?: string;
  to?: string;
  limit?: number;
  speaker?: string;
}

export interface RecordingSummary {
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

// ============================================================================
// Transcript Types
// ============================================================================

export interface TranscriptSegment {
  id: number;
  start: number;
  end: number;
  text: string;
  embedding?: number[];
  speaker?: string;
}

export interface TranscriptData {
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

// ============================================================================
// Search Result Types
// ============================================================================

export interface QueryResultSegment {
  recordingId: string;
  deviceId: string;
  recordingStartedAt: string;
  segmentStart: number;
  segmentEnd: number;
  text: string;
  relevanceScore?: number;
}

export interface ChatGPTMemory {
  timestamp: string;
  text: string;
  context: string;
  relevance: number;
}

// ============================================================================
// DynamoDB Record Types
// ============================================================================

export interface RecordingRecord {
  PK: string;
  SK: string;
  recordingId: string;
  deviceId: string;
  startedAt: string;
  endedAt?: string;
  status: string;
  transcriptS3Key?: string;
  durationSeconds?: number;
}

