variable "lambda_artifact_name" {
  type = string
}

variable "lambda_artifact_path" {
  type = string
}

variable "config" {
  type = object({
    name                  = string
    delay_ms              = number
    max_concurrency       = number
    timeout_in_seconds    = number
    expires_in_hours      = number
    max_retries           = number
    schedule_start        = string
    schedule_end          = string
    callee_url            = string
    oauth2_scope          = string
    oauth2_secret_name    = string
    oauth2_secret_arn     = string
    oauth2_token_endpoint = string
  })
}
