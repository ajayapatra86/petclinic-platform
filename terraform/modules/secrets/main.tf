locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Component = "secrets" })
}

resource "aws_secretsmanager_secret" "openai" {
  name        = "${local.name_prefix}/genai/openai-api-key"
  description = "OpenAI API key for genai-service in ${local.name_prefix}"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "openai" {
  secret_id     = aws_secretsmanager_secret.openai.id
  secret_string = var.openai_api_key
}
