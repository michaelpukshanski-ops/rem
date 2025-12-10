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

When the user asks a question about their past, use the searchMemories action to find relevant transcripts.

Always:
1. Search for relevant memories using the user's question
2. Present the findings in a conversational way
3. Include timestamps and context when available
4. If no memories are found, suggest rephrasing the question

The user's ID is "default-user" (use this in all API calls).

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
    "title": "REM Memory Search API",
    "version": "1.0.0",
    "description": "Search through audio transcripts and recordings"
  },
  "servers": [
    {
      "url": "YOUR_API_GATEWAY_URL_HERE"
    }
  ],
  "paths": {
    "/query": {
      "post": {
        "operationId": "searchMemories",
        "summary": "Search through past audio recordings and transcripts",
        "description": "Searches transcripts by keyword and time range to find relevant memories",
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
                    "description": "Natural language search query or keywords"
                  },
                  "from": {
                    "type": "string",
                    "format": "date-time",
                    "description": "Start date for search range (ISO 8601 format)"
                  },
                  "to": {
                    "type": "string",
                    "format": "date-time",
                    "description": "End date for search range (ISO 8601 format)"
                  },
                  "limit": {
                    "type": "integer",
                    "description": "Maximum number of results to return",
                    "default": 10
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful search",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "success": {
                      "type": "boolean"
                    },
                    "summary": {
                      "type": "string",
                      "description": "Human-readable summary of results"
                    },
                    "memories": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "timestamp": {
                            "type": "string",
                            "description": "When this was recorded"
                          },
                          "text": {
                            "type": "string",
                            "description": "The transcript text with context"
                          },
                          "context": {
                            "type": "string",
                            "description": "Additional context about the recording"
                          },
                          "relevance": {
                            "type": "number",
                            "description": "Relevance score (0-1)"
                          }
                        }
                      }
                    },
                    "totalMatches": {
                      "type": "integer"
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
}
```

**Replace `YOUR_API_GATEWAY_URL_HERE`** with your actual API Gateway URL (without `/query` at the end).

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

