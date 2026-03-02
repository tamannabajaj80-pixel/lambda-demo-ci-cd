# Terraform Variables

variable "lambda_function_name" {
  description = "Existing Lambda function name"
  type        = string
}

variable "lambda_execution_role_name" {
  description = "Existing Lambda execution role name"
  type        = string
}
