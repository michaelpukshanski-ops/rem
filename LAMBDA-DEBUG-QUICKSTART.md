# Lambda Local Debugging - Quick Start

Debug your Lambda functions locally on your development machine!

## 🚀 Quick Setup (5 minutes)

### 1. Run the Setup Script

```bash
# From project root
./scripts/setup-lambda-debug.sh
```

This automatically creates `.env.local` files with your AWS credentials from Terraform.

### 2. Install Dependencies

```bash
# Install for all Lambdas
cd cloud/lambdas/ingest-audio && npm install && cd -
cd cloud/lambdas/transcription-dispatcher && npm install && cd -
cd cloud/lambdas/query-transcripts && npm install && cd -
```

### 3. Run a Lambda!

```bash
# Test ingest-audio Lambda
cd cloud/lambdas/ingest-audio
npm run dev test.wav
```

---

## 📋 Available Commands

### Ingest Audio Lambda

```bash
cd cloud/lambdas/ingest-audio

# Run with test file
npm run dev /path/to/audio.wav

# Debug with breakpoints
npm run debug /path/to/audio.wav
```

### Transcription Dispatcher Lambda

```bash
cd cloud/lambdas/transcription-dispatcher

# Run with S3 key
npm run dev "raw/test-device/2024/12/10/test-device_2024-12-10T10-00-00Z_2024-12-10T10-05-00Z.wav"

# Debug with breakpoints
npm run debug
```

### Query Transcripts Lambda

```bash
cd cloud/lambdas/query-transcripts

# Run with search query
npm run dev "search term"

# Debug with breakpoints
npm run debug "search term"
```

---

## 🐛 Debugging with VS Code

### 1. Start Debug Mode

```bash
cd cloud/lambdas/ingest-audio
npm run debug
```

You'll see:
```
Debugger listening on ws://127.0.0.1:9229/...
For help, see: https://nodejs.org/en/docs/inspector
```

### 2. Create VS Code Launch Configuration

Create `.vscode/launch.json` in project root:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "attach",
      "name": "Attach to Lambda",
      "port": 9229,
      "restart": true,
      "skipFiles": ["<node_internals>/**"],
      "sourceMaps": true,
      "outFiles": ["${workspaceFolder}/cloud/lambdas/*/dist/**/*.js"]
    }
  ]
}
```

### 3. Set Breakpoints & Debug

1. Open `cloud/lambdas/ingest-audio/src/index.ts`
2. Click in the gutter (left of line numbers) to set breakpoints
3. Press **F5** or click **Run > Start Debugging**
4. The debugger will attach and pause at your breakpoints!

### 4. Debug Controls

- **F5** - Continue
- **F10** - Step Over
- **F11** - Step Into
- **Shift+F11** - Step Out
- **Shift+F5** - Stop Debugging

---

## 🔍 Debugging with Chrome DevTools

### 1. Start Debug Mode

```bash
cd cloud/lambdas/ingest-audio
npm run debug
```

### 2. Open Chrome

1. Open Chrome browser
2. Go to `chrome://inspect`
3. Click **"Open dedicated DevTools for Node"**
4. Your Lambda will appear - click **"inspect"**

### 3. Debug!

- Set breakpoints in the Sources tab
- Inspect variables in the Scope panel
- Use the Console to run commands

---

## 💡 Tips & Tricks

### Add Console Logs

```typescript
console.log('Event:', JSON.stringify(event, null, 2));
console.log('S3 Key:', s3Key);
console.log('Result:', result);
```

### Test with Real AWS

The local environment uses **real AWS resources**:
- ✅ Tests full integration
- ✅ No mocking needed
- ⚠️ Creates real data (clean up after!)

### Clean Up Test Data

```bash
# Delete test S3 files
aws s3 rm s3://rem-raw-audio-xxxxx/raw/test-device/ --recursive

# Purge SQS queue
aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/.../rem-transcription-jobs-dev
```

### Watch for Changes

Use `nodemon` for auto-restart on file changes:

```bash
npm install -g nodemon
nodemon --exec npm run dev
```

---

## 🎯 Common Use Cases

### Debug Upload Issues

```bash
cd cloud/lambdas/ingest-audio
npm run debug test.wav

# Set breakpoint in src/index.ts at line where S3 upload happens
# Press F5 in VS Code to attach
# Step through the code to see what's failing
```

### Debug DynamoDB Queries

```bash
cd cloud/lambdas/transcription-dispatcher
npm run debug "raw/test-device/2024/12/10/test.wav"

# Set breakpoint at DynamoDB query
# Inspect the query parameters and results
```

### Debug Transcript Search

```bash
cd cloud/lambdas/query-transcripts
npm run debug "search term"

# Set breakpoint at S3 download or search logic
# See exactly what's being searched
```

---

## 📚 Full Documentation

See [cloud/lambdas/README-LOCAL-DEBUG.md](cloud/lambdas/README-LOCAL-DEBUG.md) for complete documentation.

---

## 🆘 Troubleshooting

### "AWS credentials not found"

```bash
# Configure AWS CLI
aws configure

# Or add to .env.local:
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
```

### "Module not found"

```bash
# Install dependencies
cd cloud/lambdas/ingest-audio
npm install
```

### "Table/Bucket not found"

```bash
# Re-run setup script
./scripts/setup-lambda-debug.sh
```

---

## 🎉 You're Ready!

Start debugging:

```bash
cd cloud/lambdas/ingest-audio
npm run debug test.wav
```

Then press **F5** in VS Code and start stepping through your code! 🐛✨

