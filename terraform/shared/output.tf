output "oauth2_secret_name" {
  value = aws_secretsmanager_secret.event_processor_oauth2.name
}

output "oauth2_secret_arn" {
  value = aws_secretsmanager_secret.event_processor_oauth2.arn
}
