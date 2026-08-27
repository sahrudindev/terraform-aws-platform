# ============================================================================
# MODULE SERVERLESS — Lambda + API Gateway (HTTP API)
# Kode Lambda ada di folder src/ dan di-zip otomatis saat apply.
# ============================================================================

locals {
  name = "${var.project}-${var.environment}-fn"
}

# Zip kode dari folder src/ secara otomatis
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/${local.name}.zip"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name_prefix        = "${var.environment}-fn-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  #checkov:skip=CKV_AWS_338:One year of retention is a cost decision, not a security one. These logs are read during an incident, which happens within days. Raise var.log_retention_days where a compliance regime actually requires it.
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_272:Code signing requires a signing profile and a release process to sign artifacts. The deployment package is built from source in this repository at apply time, so there is no unsigned third-party artifact to guard against.
  #checkov:skip=CKV_AWS_117:Placing this function in a VPC would force a NAT Gateway at roughly $32/month and add cold-start latency, to reach an API that is deliberately public and touches nothing private.
  function_name    = local.name
  role             = aws_iam_role.lambda.arn
  runtime          = var.runtime
  handler          = var.handler
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = var.timeout
  memory_size      = var.memory_size

  reserved_concurrent_executions = var.reserved_concurrent_executions
  kms_key_arn                    = var.kms_key_arn

  tracing_config {
    mode = var.tracing_mode
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = var.environment_variables
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

# --- API Gateway HTTP API ---------------------------------------------------
resource "aws_apigatewayv2_api" "this" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "this" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  #checkov:skip=CKV_AWS_309:This route is a public demonstration endpoint returning a static payload. Adding an authorizer would be theatre; it becomes a real finding the moment the function reads anything.
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_stage" "this" {
  #checkov:skip=CKV_AWS_76:Access logging needs a log group and a format decided by what the API ends up serving. Tracked in docs/SECURITY.md rather than guessed at now.
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
