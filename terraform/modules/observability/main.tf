locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Component = "observability" })
}

resource "aws_cloudwatch_log_group" "service" {
  for_each = toset(var.service_names)

  name              = "/petclinic/${var.environment}/${each.value}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Service = each.value })
}
