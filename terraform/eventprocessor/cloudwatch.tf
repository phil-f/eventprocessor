resource "aws_cloudwatch_log_group" "event_processor" {
  name = "/aws/lambda/${aws_lambda_function.event_processor.function_name}"
}
