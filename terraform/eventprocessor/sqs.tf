resource "aws_sqs_queue" "event_processor" {
  name                      = var.config.name
  message_retention_seconds = var.config.expires_in_hours * 3600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.event_processor_dlq.arn
    maxReceiveCount     = 1
  })
}

resource "aws_sqs_queue" "event_processor_dlq" {
  name = "${var.config.name}-dlq"
}

resource "aws_lambda_event_source_mapping" "event_processor_sqs" {
  event_source_arn = aws_sqs_queue.event_processor.arn
  function_name    = aws_lambda_function.event_processor.arn
  batch_size       = 1

  scaling_config {
    maximum_concurrency = var.config.max_concurrency
  }

  lifecycle {
    ignore_changes = [
      enabled
    ]
  }
}
