output "log_group_names" {
  description = "Map of service_name → CloudWatch log group name"
  value       = { for k, v in aws_cloudwatch_log_group.service : k => v.name }
}
