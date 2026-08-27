# ============================================================================
# Failure handling and tracing for the function.
# ============================================================================

# Asynchronous invocations that exhaust their retries land here instead of
# disappearing.
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name}-dlq"
  message_retention_seconds = 1209600 # 14 days, the maximum
  sqs_managed_sse_enabled   = true

  tags = { Name = "${local.name}-dlq" }
}

data "aws_iam_policy_document" "dlq" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]
  }
}

resource "aws_iam_role_policy" "dlq" {
  name   = "publish-to-dlq"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.dlq.json
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
