variable "lambda_artifact_name" {
  type    = string
  default = "eventprocessor.zip"
}

variable "lambda_artifact_path" {
  type    = string
  default = "../eventprocessor.zip"
}

variable "oauth2_token_endpoint" {
  type = string
}

variable "oauth2_client_id" {
  type      = string
  sensitive = true
}

variable "oauth2_client_secret" {
  type      = string
  sensitive = true
}
