/**
 * Local test runner for query-transcripts Lambda
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

// Create a mock API Gateway event
function createMockEvent(query: string, userId?: string, deviceId?: string, limit?: number) {
  return {
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      query,
      userId,
      deviceId,
      limit: limit || 10,
    }),
    requestContext: {
      requestId: 'local-test-' + Date.now(),
    },
  };
}

async function main() {
  console.log('🚀 Starting local Lambda test...\n');
  
  // Load environment
  loadEnv();
  
  // Get query from command line or use default
  const query = process.argv[2] || 'test';
  const userId = process.argv[3];
  const deviceId = process.argv[4];
  
  console.log(`🔍 Query: "${query}"`);
  if (userId) console.log(`👤 User ID: ${userId}`);
  if (deviceId) console.log(`📱 Device ID: ${deviceId}`);
  console.log('');
  
  // Create mock event
  const event = createMockEvent(query, userId, deviceId);
  
  console.log('📤 Invoking Lambda handler...\n');
  
  try {
    const result = await handler(event as any);
    
    console.log('✅ Lambda execution completed!\n');
    console.log('📋 Response:');
    console.log('Status Code:', result.statusCode);
    
    const body = JSON.parse(result.body);
    console.log('Results:', JSON.stringify(body, null, 2));
    
    if (result.statusCode === 200) {
      console.log(`\n🎉 Found ${body.results?.length || 0} results!`);
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

