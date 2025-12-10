#!/bin/bash
# Deploy updated query-transcripts Lambda function

set -e

# Get the absolute path to the repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Deploying query-transcripts Lambda..."
echo ""

# Build the Lambda
echo "📦 Building Lambda function..."
cd "$REPO_ROOT/cloud/lambdas/query-transcripts"

npm install
npm run build

if [ ! -f "dist/function.zip" ]; then
  echo "❌ Error: dist/function.zip not found after build"
  exit 1
fi

echo "✅ Lambda built successfully"
echo ""

# Deploy with Terraform
echo "🔧 Deploying with Terraform..."
cd "$REPO_ROOT/cloud/infra"

terraform apply -target=aws_lambda_function.query_transcripts -auto-approve

echo ""
echo "✅ Deployment complete!"
echo ""

# Get the API endpoint
API_URL=$(terraform output -raw api_gateway_query_url 2>/dev/null || echo "")

if [ -n "$API_URL" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📡 API ENDPOINT"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Use this URL in your ChatGPT Custom GPT:"
  echo "$API_URL"
  echo ""
  echo "Base URL (for OpenAPI schema):"
  echo "${API_URL%/query}"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 TEST THE API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Test with curl:"
echo ""
echo "curl -X POST \"$API_URL\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"userId\":\"default-user\",\"query\":\"test\",\"limit\":5}'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 Next steps:"
echo "1. Follow CHATGPT-INTEGRATION.md to set up ChatGPT Custom GPT"
echo "2. Test the API with the curl command above"
echo "3. Start asking ChatGPT about your memories!"
echo ""

