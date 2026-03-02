# Terraform Configuration for Complete Serverless Architecture

provider "aws" {
  region = "ap-south-1"  # Match your Lambda region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "lambda-demo-ci-cd"
}

# 1. SQS Queue for Message Processing
resource "aws_sqs_queue" "lambda_queue" {
  name                          = "${var.project_name}-queue"
  visibility_timeout_seconds    = 30
  message_retention_seconds     = 1209600 # 14 days
  receive_wait_time_seconds     = 20      # Long polling
  
  tags = {
    Name        = "${var.project_name}-queue"
    Environment = "demo"
  }
}

# 2. API Gateway for HTTP Endpoints
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  
  tags = {
    Name        = "${var.project_name}-api"
    Environment = "demo"
  }
}

# API Gateway Integration with SQS
resource "aws_apigatewayv2_integration" "sqs_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS"
  
  connection_type           = "INTERNET"
  description              = "SQS integration"
  integration_uri          = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${var.project_name}-queue"
  credentials_arn          = aws_iam_role.api_gateway_sqs_role.arn
  
  request_parameters = {
    "append:header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
}

# Data source for current region
data "aws_region" "current" {}

# API Gateway Route
resource "aws_apigatewayv2_route" "sqs_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /messages"
  
  target = "integrations/${aws_apigatewayv2_integration.sqs_integration.id}"
}

# API Gateway Deployment
resource "aws_apigatewayv2_deployment" "main" {
  api_id = aws_apigatewayv2_api.main.id
  
  depends_on = [aws_apigatewayv2_route.sqs_route]
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  deployment_id = aws_apigatewayv2_deployment.main.id
  
  auto_deploy = true
}

# 3. Use existing IAM Role for API Gateway to access SQS
data "aws_iam_role" "api_gateway_sqs_role" {
  name = "lambda-demo-ci-cd-api-sqs-role-v2"
}

# IAM Policy for API Gateway
resource "aws_iam_role_policy" "api_gateway_sqs_policy" {
  name = "${var.project_name}-api-sqs-policy"
  role = data.aws_iam_role.api_gateway_sqs_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.lambda_queue.arn
      }
    ]
  })
}

# 5. Lambda Event Source Mapping (SQS Trigger)
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.lambda_queue.arn
  function_name    = var.lambda_function_name
  
  batch_size        = 5  # Process 5 messages at once
  maximum_batching_window_in_seconds = 10
  
  depends_on = [aws_iam_role_policy_attachment.lambda_sqs_policy]
}

# 6. Use existing IAM Policy for Lambda SQS access
data "aws_iam_policy" "lambda_sqs_policy" {
  name = "lambda-demo-ci-cd-lambda-sqs-policy-v2"
}

# Lambda IAM Role for SQS access
resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  role       = var.lambda_execution_role_name
  policy_arn = data.aws_iam_policy.lambda_sqs_policy.arn
}

# Output Variables
output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = aws_sqs_queue.lambda_queue.id
}

output "sqs_queue_arn" {
  description = "SQS Queue ARN"
  value       = aws_sqs_queue.lambda_queue.arn
}

output "api_gateway_endpoint" {
  description = "API Gateway Endpoint URL"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/messages"
}

output "lambda_event_source_mapping_uuid" {
  description = "Lambda Event Source Mapping UUID"
  value       = aws_lambda_event_source_mapping.sqs_lambda_trigger.uuid
}

output "existing_lambda_function_url" {
  description = "Existing Lambda Function URL"
  value       = "https://jxmv5nfxua7xh6gbdjt7d2fmby0cpvfd.lambda-url.ap-south-1.on.aws/"
}
