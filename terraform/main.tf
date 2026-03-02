# Terraform Configuration for Complete Serverless Architecture

provider "aws" {
  region = var.aws_region
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
  integration_type = "AWS_PROXY"
  
  connection_type           = "INTERNET"
  description              = "SQS integration"
  integration_uri          = "arn:aws:apigateway:${var.aws_region}:sqs:path/${var.project_name}-queue"
  credentials_arn          = aws_iam_role.api_gateway_sqs_role.arn
  
  request_parameters = {
    "append:header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
}

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

# 3. IAM Role for API Gateway to access SQS
resource "aws_iam_role" "api_gateway_sqs_role" {
  name = "${var.project_name}-api-sqs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for API Gateway
resource "aws_iam_role_policy" "api_gateway_sqs_policy" {
  name = "${var.project_name}-api-sqs-policy"
  role = aws_iam_role.api_gateway_sqs_role.id
  
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

# 6. Lambda Functional URL (if not exists)
resource "aws_lambda_function_url" "lambda_url" {
  function_name = var.lambda_function_name
  authorization_type = "NONE"
  
  depends_on = [aws_iam_role_policy_attachment.lambda_url_policy]
}

# Lambda URL Permissions
resource "aws_lambda_permission" "allow_url_access" {
  statement_id  = "FunctionURLAllowPublicAccess"
  action        = "lambda:InvokeFunctionUrl"
  function_name = var.lambda_function_name
  principal     = "*"
}

# Lambda URL IAM Policy
resource "aws_iam_role_policy_attachment" "lambda_url_policy" {
  role       = var.lambda_execution_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 7. Lambda IAM Role for SQS access
resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  role       = var.lambda_execution_role_name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

resource "aws_iam_policy" "lambda_sqs_policy" {
  name = "${var.project_name}-lambda-sqs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.lambda_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
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

output "lambda_function_url" {
  description = "Lambda Function URL"
  value       = aws_lambda_function_url.lambda_url.function_url
}

output "lambda_event_source_mapping_uuid" {
  description = "Lambda Event Source Mapping UUID"
  value       = aws_lambda_event_source_mapping.sqs_lambda_trigger.uuid
}
