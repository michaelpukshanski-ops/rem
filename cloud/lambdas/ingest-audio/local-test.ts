/**
 * Local test runner for ingest-audio Lambda
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

// Create a mock multipart/form-data request
function createMockEvent(audioFilePath: string) {
  const audioData = fs.readFileSync(audioFilePath);
  const boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
  
  const deviceId = 'test-device';
  const startedAt = new Date().toISOString();
  const endedAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  
  // Build multipart form data
  const parts = [
    `------${boundary}`,
    'Content-Disposition: form-data; name="deviceId"',
    '',
    deviceId,
    `------${boundary}`,
    'Content-Disposition: form-data; name="startedAt"',
    '',
    startedAt,
    `------${boundary}`,
    'Content-Disposition: form-data; name="endedAt"',
    '',
    endedAt,
    `------${boundary}`,
    'Content-Disposition: form-data; name="file"; filename="test.wav"',
    'Content-Type: audio/wav',
    '',
  ];
  
  const header = Buffer.from(parts.join('\r\n') + '\r\n', 'utf-8');
  const footer = Buffer.from(`\r\n------${boundary}--\r\n`, 'utf-8');
  const body = Buffer.concat([header, audioData, footer]);
  
  return {
    headers: {
      'content-type': `multipart/form-data; boundary=----${boundary}`,
      'x-api-key': process.env.API_KEY || 'test-key',
    },
    body: body.toString('base64'),
    isBase64Encoded: true,
    requestContext: {
      requestId: 'local-test-' + Date.now(),
    },
  };
}

async function main() {
  console.log('🚀 Starting local Lambda test...\n');
  
  // Load environment
  loadEnv();
  
  // Get audio file path from command line or use default
  const audioFilePath = process.argv[2] || path.join(__dirname, '../../../test.wav');
  
  if (!fs.existsSync(audioFilePath)) {
    console.error(`❌ Audio file not found: ${audioFilePath}`);
    console.log('Usage: npm run dev [path-to-audio-file.wav]');
    process.exit(1);
  }
  
  console.log(`📁 Audio file: ${audioFilePath}`);
  console.log(`📊 File size: ${(fs.statSync(audioFilePath).size / 1024 / 1024).toFixed(2)} MB\n`);
  
  // Create mock event
  const event = createMockEvent(audioFilePath);
  
  console.log('📤 Invoking Lambda handler...\n');
  
  try {
    const result = await handler(event as any);
    
    console.log('✅ Lambda execution completed!\n');
    console.log('📋 Response:');
    console.log('Status Code:', result.statusCode);
    console.log('Body:', JSON.parse(result.body));
    
    if (result.statusCode === 200) {
      console.log('\n🎉 Success! Audio uploaded to S3 and DynamoDB record created.');
    } else {
      console.log('\n❌ Request failed. Check the error message above.');
    }
  } catch (error) {
    console.error('❌ Lambda execution failed:');
    console.error(error);
    process.exit(1);
  }
}

main();

