resource "aws_scheduler_schedule" "enable_event_processor" {
  name = "enable-${aws_lambda_function.event_processor.function_name}"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(${var.config.schedule_start})"
  schedule_expression_timezone = "Europe/London"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:lambda:updateEventSourceMapping"
    role_arn = aws_iam_role.event_processor_scheduler.arn

    input = jsonencode({
      Uuid    = aws_lambda_event_source_mapping.event_processor_sqs.uuid
      Enabled = true
    })
  }
}

resource "aws_scheduler_schedule" "disable_event_processor" {
  name = "disable-${aws_lambda_function.event_processor.function_name}"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(${var.config.schedule_end})"
  schedule_expression_timezone = "Europe/London"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:lambda:updateEventSourceMapping"
    role_arn = aws_iam_role.event_processor_scheduler.arn

    input = jsonencode({
      Uuid    = aws_lambda_event_source_mapping.event_processor_sqs.uuid
      Enabled = false
    })
  }
}

resource "aws_iam_role" "event_processor_scheduler" {
  name = "disable-${aws_lambda_function.event_processor.function_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "scheduler.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "event_processor_scheduler" {
  name = "${aws_lambda_function.event_processor.function_name}-scheduler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:UpdateEventSourceMapping"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:lambda:${local.region}:${local.account_id}:event-source-mapping:${aws_lambda_event_source_mapping.event_processor_sqs.uuid}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_processor_scheduler" {
  role       = aws_iam_role.event_processor_scheduler.name
  policy_arn = aws_iam_policy.event_processor_scheduler.arn
}
