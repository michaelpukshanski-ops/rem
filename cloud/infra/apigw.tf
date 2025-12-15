# API Gateway HTTP API for REM System

resource "aws_apigatewayv2_api" "rem" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]  # Restrict in production
    allow_methods = ["POST", "GET", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "x-api-key", "x-clerk-user-id", "authorization"]
    max_age       = 300
  }
  
  tags = {
    Name = "REM API Gateway"
  }
}

# ============================================================================
# Ingest Audio Route
# ============================================================================

resource "aws_apigatewayv2_integration" "ingest_audio" {
  api_id           = aws_apigatewayv2_api.rem.id
  integration_type = "AWS_PROXY"
  
  integration_uri    = aws_lambda_function.ingest_audio.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ingest_audio" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "POST /ingest"
  
  target = "integrations/${aws_apigatewayv2_integration.ingest_audio.id}"
}

resource "aws_lambda_permission" "apigw_ingest_audio" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_audio.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.rem.execution_arn}/*/*"
}

# ============================================================================
# Query Transcripts Route
# ============================================================================

resource "aws_apigatewayv2_integration" "query_transcripts" {
  api_id           = aws_apigatewayv2_api.rem.id
  integration_type = "AWS_PROXY"
  
  integration_uri    = aws_lambda_function.query_transcripts.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "query_transcripts" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "POST /query"
  
  target = "integrations/${aws_apigatewayv2_integration.query_transcripts.id}"
}

resource "aws_lambda_permission" "apigw_query_transcripts" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_transcripts.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.rem.execution_arn}/*/*"
}

# ============================================================================
# List Recordings Route (GET /recordings)
# ============================================================================

resource "aws_apigatewayv2_route" "list_recordings" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "GET /recordings"

  target = "integrations/${aws_apigatewayv2_integration.query_transcripts.id}"
}

# ============================================================================
# Get Transcript Route (GET /transcript/{recordingId})
# ============================================================================

resource "aws_apigatewayv2_route" "get_transcript" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "GET /transcript/{recordingId}"

  target = "integrations/${aws_apigatewayv2_integration.query_transcripts.id}"
}

# ============================================================================
# User Lookup Route (POST /user)
# ============================================================================

resource "aws_apigatewayv2_route" "user_lookup" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "POST /user"

  target = "integrations/${aws_apigatewayv2_integration.query_transcripts.id}"
}

# ============================================================================
# Speakers API Routes
# ============================================================================

resource "aws_apigatewayv2_integration" "speakers_api" {
  api_id           = aws_apigatewayv2_api.rem.id
  integration_type = "AWS_PROXY"

  integration_uri    = aws_lambda_function.speakers_api.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# GET /speakers - List all speakers
resource "aws_apigatewayv2_route" "list_speakers" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "GET /speakers"

  target = "integrations/${aws_apigatewayv2_integration.speakers_api.id}"
}

# GET /speakers/{speakerId} - Get specific speaker
resource "aws_apigatewayv2_route" "get_speaker" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "GET /speakers/{speakerId}"

  target = "integrations/${aws_apigatewayv2_integration.speakers_api.id}"
}

# PUT /speakers/{speakerId} - Update speaker (rename)
resource "aws_apigatewayv2_route" "update_speaker" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "PUT /speakers/{speakerId}"

  target = "integrations/${aws_apigatewayv2_integration.speakers_api.id}"
}

# DELETE /speakers/{speakerId} - Delete speaker
resource "aws_apigatewayv2_route" "delete_speaker" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "DELETE /speakers/{speakerId}"

  target = "integrations/${aws_apigatewayv2_integration.speakers_api.id}"
}

# OPTIONS /speakers - CORS preflight
resource "aws_apigatewayv2_route" "speakers_options" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "OPTIONS /speakers"

  target = "integrations/${aws_apigatewayv2_integration.speakers_api.id}"
}

# OPTIONS /speakers/{speakerId} - CORS preflight
resource "aws_apigatewayv2_route" "speaker_options" {
  api_id    = aws_apigatewayv2_api.rem.id
  route_key = "OPTIONS /speakers/{speakerId}"

  target = "integrations/${aws_apigatewayv2_integration.speakers_api.id}"
}

resource "aws_lambda_permission" "apigw_speakers_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.speakers_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.rem.execution_arn}/*/*"
}

# ============================================================================
# API Gateway Stage
# ============================================================================

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.rem.id
  name        = "$default"
  auto_deploy = true
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }
  
  default_route_settings {
    throttling_burst_limit = var.api_throttle_burst_limit
    throttling_rate_limit  = var.api_throttle_rate_limit
  }

  tags = {
    Name = "REM API Default Stage"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 14
}

# ============================================================================
# Custom Domain (Optional)
# ============================================================================

# Uncomment and configure if you have a custom domain
# resource "aws_apigatewayv2_domain_name" "rem" {
#   domain_name = "api.yourdomain.com"
#   
#   domain_name_configuration {
#     certificate_arn = aws_acm_certificate.api.arn
#     endpoint_type   = "REGIONAL"
#     security_policy = "TLS_1_2"
#   }
# }
#
# resource "aws_apigatewayv2_api_mapping" "rem" {
#   api_id      = aws_apigatewayv2_api.rem.id
#   domain_name = aws_apigatewayv2_domain_name.rem.id
#   stage       = aws_apigatewayv2_stage.default.id
# }

