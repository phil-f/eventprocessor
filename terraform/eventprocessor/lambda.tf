resource "aws_lambda_function" "event_processor" {
  filename         = var.lambda_artifact_path
  function_name    = "${var.config.name}-event-processor"
  role             = aws_iam_role.event_processor.arn
  handler          = "bootstrap"
  source_code_hash = filebase64sha256(var.lambda_artifact_path)
  runtime          = "provided.al2"
  architectures    = ["arm64"]
  timeout          = var.config.timeout_in_seconds

  environment {
    variables = {
      EXPIRES_IN_HOURS   = var.config.expires_in_hours
      DELAY_MS           = var.config.delay_ms
      MAX_RETRIES        = var.config.max_retries
      CALLEE_URL         = var.config.callee_url
      OAUTH2_SECRET_NAME = var.config.oauth2_secret_name
      OAUTH2_TOKEN_URL   = var.config.oauth2_token_endpoint
      OAUTH2_SCOPE       = var.config.oauth2_scope
    }
  }
}


resource "aws_lambda_permission" "event_processor_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_processor.arn
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.event_processor.arn
}

resource "aws_iam_role" "event_processor" {
  name = "${var.config.name}-event-processor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""

        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "event_processor_sqs" {
  name = "${var.config.name}-event-processor-sqs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.event_processor.arn
      }
    ]
  })
}

resource "aws_iam_policy" "event_processor_cloudwatch_logs" {
  name = "${var.config.name}-event-processor-cloudwatch-logs"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : "${aws_cloudwatch_log_group.event_processor.arn}:*"
      }
    ]
  })
}

resource "aws_iam_policy" "event_processor_secrets_manager" {
  name = "${var.config.name}-event-processor-secrets-manager"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ],
        Resource : var.config.oauth2_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_processor_sqs" {
  policy_arn = aws_iam_policy.event_processor_sqs.arn
  role       = aws_iam_role.event_processor.name
}

resource "aws_iam_role_policy_attachment" "event_processor_cloudwatch_logs" {
  role       = aws_iam_role.event_processor.name
  policy_arn = aws_iam_policy.event_processor_cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "event_processor_secrets_manager" {
  role       = aws_iam_role.event_processor.name
  policy_arn = aws_iam_policy.event_processor_secrets_manager.arn
}
