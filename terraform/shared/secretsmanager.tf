resource "aws_secretsmanager_secret" "event_processor_oauth2" {
  name = "event-processor-oauth2"
}

resource "aws_secretsmanager_secret_version" "event_processor_oauth2" {
  secret_id = aws_secretsmanager_secret.event_processor_oauth2.id
  secret_string = jsonencode({
    clientId     = var.oauth2_client_id
    clientSecret = var.oauth2_client_secret
  })
}
