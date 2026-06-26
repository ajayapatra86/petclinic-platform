output "karpenter_role_arn" {
  description = "Karpenter controller IRSA role ARN"
  value       = aws_iam_role.karpenter.arn
}

output "karpenter_queue_name" {
  description = "SQS interruption queue name"
  value       = aws_sqs_queue.karpenter.name
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter-launched nodes"
  value       = aws_iam_instance_profile.karpenter.name
}
