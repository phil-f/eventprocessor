terraform {
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {}

module "shared" {
  source = "./shared"

  oauth2_client_id     = var.oauth2_client_id
  oauth2_client_secret = var.oauth2_client_secret
}

module "eventprocessor" {
  for_each = { for cfg in local.config : cfg.name => cfg }

  source = "./eventprocessor"

  lambda_artifact_name = var.lambda_artifact_name
  lambda_artifact_path = var.lambda_artifact_path
  config = merge(each.value, {
    oauth2_secret_name    = module.shared.oauth2_secret_name
    oauth2_secret_arn     = module.shared.oauth2_secret_arn
    oauth2_token_endpoint = var.oauth2_token_endpoint
  })
}
