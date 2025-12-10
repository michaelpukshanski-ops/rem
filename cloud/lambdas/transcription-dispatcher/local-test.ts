/**
 * Local test runner for transcription-dispatcher Lambda
 * Run with: npm run dev
 */

import { handler } from './src/index';
import * as fs from 'fs';
import * as path from 'path';

// Load environment variables from .env file
function loadEnv() {
  const envPath = path.join(__dirname, '.env.local');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf-8');
    envContent.split('\n').forEach(line => {
      const [key, ...valueParts] = line.split('=');
      if (key && valueParts.length > 0) {
        process.env[key.trim()] = valueParts.join('=').trim();
      }
    });
    console.log('✅ Loaded environment variables from .env.local');
  } else {
    console.error('❌ .env.local not found. Create it with your AWS credentials.');
    process.exit(1);
  }
}

// Create a mock S3 event
function createMockS3Event(s3Key: string, bucketName: string) {
  return {
    Records: [
      {
        eventVersion: '2.1',
        eventSource: 'aws:s3',
        awsRegion: process.env.AWS_REGION || 'us-east-1',
        eventTime: new Date().toISOString(),
        eventName: 'ObjectCreated:Put',
        s3: {
          s3SchemaVersion: '1.0',
          configurationId: 'local-test',
          bucket: {
            name: bucketName,
            arn: `arn:aws:s3:::${bucketName}`,
          },
          object: {
            key: s3Key,
            size: 1024000,
          },
        },
      },
    ],
  };
}

async function main() {
  console.log('🚀 Starting local Lambda test...\n');
  
  // Load environment
  loadEnv();
  
  // Get S3 key from command line or use default
  const s3Key = process.argv[2] || 'raw/test-device/2024/12/10/test-device_2024-12-10T10-00-00Z_2024-12-10T10-05-00Z.wav';
  const bucketName = process.env.RAW_AUDIO_BUCKET || 'rem-raw-audio-dev';
  
  console.log(`📁 S3 Key: ${s3Key}`);
  console.log(`🪣 Bucket: ${bucketName}\n`);
  
  // Create mock event
  const event = createMockS3Event(s3Key, bucketName);
  
  console.log('📤 Invoking Lambda handler...\n');
  
  try {
    await handler(event as any);
    
    console.log('\n✅ Lambda execution completed!');
    console.log('🎉 Check the logs above for details.');
    console.log('💡 The job should now be in SQS queue.');
  } catch (error) {
    console.error('\n❌ Lambda execution failed:');
    console.error(error);
    process.exit(1);
  }
}

main();

