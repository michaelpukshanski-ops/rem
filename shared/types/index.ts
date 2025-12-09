/**
 * Shared TypeScript types for REM system
 * Used across all Lambda functions and cloud components
 */

// ============================================================================
// Recording Metadata
// ============================================================================

export interface RecordingMetadata {
  userId: string;
  deviceId: string;
  recordingId: string;
  s3KeyRaw: string;
  startedAt: string; // ISO 8601
  endedAt: string; // ISO 8601
  status: RecordingStatus;
  transcriptS3Key?: string;
  language?: string;
  durationSeconds?: number;
  fileSizeBytes?: number;
  createdAt: string; // ISO 8601
  updatedAt: string; // ISO 8601
}

export enum RecordingStatus {
  UPLOADED = 'UPLOADED',
  TRANSCRIBING = 'TRANSCRIBING',
  TRANSCRIBED = 'TRANSCRIBED',
  ERROR = 'ERROR',
}

// ============================================================================
// Transcription Data
// ============================================================================

export interface TranscriptSegment {
  id: number;
  start: number; // seconds
  end: number; // seconds
  text: string;
}

export interface TranscriptData {
  recordingId: string;
  userId: string;
  deviceId: string;
  language: string;
  segments: TranscriptSegment[];
  fullText: string;
  durationSeconds: number;
  transcribedAt: string; // ISO 8601
  whisperModel: string;
}

// ============================================================================
// SQS Messages
// ============================================================================

export interface TranscriptionJobMessage {
  recordingId: string;
  bucket: string;
  key: string;
  userId: string;
  deviceId: string;
  startedAt: string;
  endedAt: string;
}

// ============================================================================
// API Request/Response Types
// ============================================================================

// Ingest API
export interface IngestRequest {
  deviceId: string;
  startedAt: string;
  endedAt: string;
  // file is in multipart form data
}

export interface IngestResponse {
  success: boolean;
  recordingId: string;
  message?: string;
}

// Query API
export interface QueryRequest {
  userId: string;
  query: string;
  from?: string; // ISO 8601
  to?: string; // ISO 8601
  limit?: number;
}

export interface QueryResultSegment {
  recordingId: string;
  deviceId: string;
  recordingStartedAt: string;
  segmentStart: number;
  segmentEnd: number;
  text: string;
  relevanceScore?: number;
}

export interface QueryResponse {
  success: boolean;
  results: QueryResultSegment[];
  totalMatches: number;
  message?: string;
}

// ============================================================================
// DynamoDB Item Types
// ============================================================================

export interface RemRecordingItem {
  PK: string; // userId
  SK: string; // recordingId
  GSI1PK: string; // deviceId
  GSI1SK: string; // startedAt
  recordingId: string;
  deviceId: string;
  s3KeyRaw: string;
  startedAt: string;
  endedAt: string;
  status: RecordingStatus;
  transcriptS3Key?: string;
  language?: string;
  durationSeconds?: number;
  fileSizeBytes?: number;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// Error Types
// ============================================================================

export class RemError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code: string = 'INTERNAL_ERROR'
  ) {
    super(message);
    this.name = 'RemError';
  }
}

export class ValidationError extends RemError {
  constructor(message: string) {
    super(message, 400, 'VALIDATION_ERROR');
    this.name = 'ValidationError';
  }
}

export class AuthenticationError extends RemError {
  constructor(message: string) {
    super(message, 401, 'AUTHENTICATION_ERROR');
    this.name = 'AuthenticationError';
  }
}

export class NotFoundError extends RemError {
  constructor(message: string) {
    super(message, 404, 'NOT_FOUND');
    this.name = 'NotFoundError';
  }
}

