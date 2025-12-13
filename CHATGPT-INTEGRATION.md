# ChatGPT Integration Guide

This guide explains how to connect ChatGPT to your REM (Recording & Memory) system so you can ask questions about your past recordings.

---

## 🎯 What This Does

ChatGPT can now:
- ✅ Search through all your transcribed audio recordings
- ✅ Answer questions about your past conversations, meetings, and thoughts
- ✅ Find specific topics or keywords across all your memories
- ✅ Provide context with timestamps and dates

---

## 🚀 Setup: ChatGPT Custom GPT

### **Step 1: Get Your API Endpoint**

On your **deployment computer**:

```bash
cd cloud/infra
terraform output api_gateway_query_url
```

Copy the URL (e.g., `https://abc123.execute-api.us-east-1.amazonaws.com/query`)

### **Step 2: Create Custom GPT**

1. Go to [ChatGPT](https://chat.openai.com/)
2. Click your profile → **My GPTs** → **Create a GPT**
3. Configure:

**Name:** `My Memory Assistant`

**Description:** `Searches through my audio recordings and transcripts to answer questions about my past.`

**Instructions:**
```
You are a personal memory assistant that helps the user recall information from their past audio recordings.

You have THREE tools available:
1. listRecordings - List recent recordings with metadata (duration, topics, summary)
2. getTranscript - Get the FULL transcript of a specific recording
3. searchMemories - Search for specific keywords/topics across all recordings

STRATEGY FOR DIFFERENT REQUESTS:

For "summarize a meeting" or "what happened in my last recording":
1. First call listRecordings to see recent recordings
2. Pick the most relevant one based on duration/topics
3. Call getTranscript with that recordingId
4. Summarize the full transcript

For "find mentions of X" or "what did I say about Y":
1. Call searchMemories with the topic/keyword
2. Present the matching segments with context

For "what meetings did I have this week":
1. Call listRecordings with date range
2. Summarize the list

IMPORTANT:
- Do NOT ask for date ranges unless the user specifically mentions a time period
- Always use userId: "default-user"
- When summarizing, read the FULL transcript first using getTranscript
- Be conversational and helpful

Format your responses naturally, as if you're helping them remember something.
```

**Conversation starters:**
- "What did I discuss about work last week?"
- "Find conversations about my project deadlines"
- "What did I say about my vacation plans?"
- "Search my recordings from December 1-10"

### **Step 3: Add API Action**

Click **Actions** → **Create new action**

**Authentication:** None (or API Key if you add auth later)

**Schema:**
```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "REM Memory API",
    "version": "2.0.0",
    "description": "Access audio recordings, transcripts, and search through memories"
  },
  "servers": [
    {
      "url": "YOUR_API_GATEWAY_URL_HERE"
    }
  ],
  "paths": {
    "/recordings": {
      "get": {
        "operationId": "listRecordings",
        "summary": "List recent recordings with metadata",
        "description": "Returns a list of recordings with duration, topics, summary, and other metadata. Use this first to find recordings, then use getTranscript to read the full content.",
        "parameters": [
          {
            "name": "userId",
            "in": "query",
            "required": false,
            "schema": { "type": "string", "default": "default-user" },
            "description": "User ID (always use 'default-user')"
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": { "type": "integer", "default": 20 },
            "description": "Maximum number of recordings to return"
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": { "type": "string", "format": "date-time" },
            "description": "Start date filter (ISO 8601)"
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": { "type": "string", "format": "date-time" },
            "description": "End date filter (ISO 8601)"
          }
        ],
        "responses": {
          "200": {
            "description": "List of recordings",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "success": { "type": "boolean" },
                    "recordings": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "recordingId": { "type": "string", "description": "Unique ID to use with getTranscript" },
                          "startedAt": { "type": "string", "description": "When the recording started" },
                          "durationSeconds": { "type": "number", "description": "Length of recording" },
                          "summary": { "type": "string", "description": "Brief summary of content" },
                          "topics": { "type": "array", "items": { "type": "string" }, "description": "Main topics discussed" },
                          "speakers": { "type": "array", "items": { "type": "string" }, "description": "Identified speakers" },
                          "wordCount": { "type": "integer", "description": "Number of words in transcript" }
                        }
                      }
                    },
                    "count": { "type": "integer" }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/transcript/{recordingId}": {
      "get": {
        "operationId": "getTranscript",
        "summary": "Get full transcript for a recording",
        "description": "Returns the complete transcript text and segments for a specific recording. Use this to read the full content of a recording for summarization or detailed analysis.",
        "parameters": [
          {
            "name": "recordingId",
            "in": "path",
            "required": true,
            "schema": { "type": "string" },
            "description": "Recording ID from listRecordings"
          },
          {
            "name": "userId",
            "in": "query",
            "required": false,
            "schema": { "type": "string", "default": "default-user" },
            "description": "User ID (always use 'default-user')"
          }
        ],
        "responses": {
          "200": {
            "description": "Full transcript",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "success": { "type": "boolean" },
                    "recordingId": { "type": "string" },
                    "startedAt": { "type": "string" },
                    "durationSeconds": { "type": "number" },
                    "language": { "type": "string" },
                    "fullText": { "type": "string", "description": "Complete transcript text" },
                    "summary": { "type": "string" },
                    "topics": { "type": "array", "items": { "type": "string" } },
                    "speakers": { "type": "array", "items": { "type": "string" } },
                    "segments": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "start": { "type": "number" },
                          "end": { "type": "number" },
                          "text": { "type": "string" },
                          "speaker": { "type": "string" }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/query": {
      "post": {
        "operationId": "searchMemories",
        "summary": "Search for specific content across all recordings",
        "description": "Searches transcripts by keyword to find specific mentions or topics. Returns matching segments with context. Use this when looking for specific keywords or topics.",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["userId", "query"],
                "properties": {
                  "userId": {
                    "type": "string",
                    "description": "User ID (always use 'default-user')",
                    "default": "default-user"
                  },
                  "query": {
                    "type": "string",
                    "description": "Keywords or topic to search for"
                  },
                  "limit": {
                    "type": "integer",
                    "description": "Maximum results",
                    "default": 10
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Search results",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "success": { "type": "boolean" },
                    "summary": { "type": "string" },
                    "memories": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "timestamp": { "type": "string" },
                          "text": { "type": "string" },
                          "context": { "type": "string" },
                          "relevance": { "type": "number" }
                        }
                      }
                    },
                    "totalMatches": { "type": "integer" }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

**Replace `YOUR_API_GATEWAY_URL_HERE`** with your API Gateway base URL. Get it with:
```bash
cd cloud/infra && terraform output api_gateway_base_url
```

### **Step 4: Test It**

Click **Test** in the Actions panel and try:

```json
{
  "userId": "default-user",
  "query": "project deadline",
  "limit": 5
}
```

You should see results from your transcripts!

---

## 📊 Example Usage

**User:** "What did I discuss about work last week?"

**ChatGPT:** 
> I found 3 relevant memories from last week:
> 
> 1. **December 5, 2025 at 2:30 PM**
>    "We need to finish the project by Friday. The client is expecting the final deliverables..."
>    
> 2. **December 6, 2025 at 10:15 AM**
>    "Had a meeting with the team about the deadline. Everyone agreed we can make it if we focus..."
>    
> 3. **December 7, 2025 at 4:00 PM**
>    "Finished the main features. Just need to do testing and documentation before Friday..."

---

## 🔒 Security (Optional)

To add API key authentication:

1. Add API key to API Gateway (see Terraform docs)
2. Update Custom GPT action authentication to use API Key
3. Store the key securely in ChatGPT's action settings

---

## 🎉 You're Done!

Now you can ask ChatGPT questions about your past and it will search through all your recordings!

**Example questions:**
- "What did I say about my vacation plans?"
- "Find conversations from last Monday"
- "What meetings did I have about the budget?"
- "Search for discussions about hiring"

---

## 🐛 Troubleshooting

**No results found:**
- Make sure you have transcribed recordings in S3
- Check that the userId is "default-user"
- Try broader search terms

**API errors:**
- Verify the API Gateway URL is correct
- Check CloudWatch logs: `/aws/lambda/rem-query-transcripts-dev`
- Ensure Lambda has been deployed with latest code

**Deploy updated Lambda:**
```bash
cd cloud/lambdas/query-transcripts
npm install && npm run build
cd ../../infra
terraform apply
```

