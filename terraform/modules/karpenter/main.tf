locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Component = "karpenter" })

  oidc_provider_url = replace(var.oidc_provider_arn, "/^.*oidc-provider//", "")
}

# ── SQS interruption queue ────────────────────────────────────────────────────

resource "aws_sqs_queue" "karpenter" {
  name                      = "${local.name_prefix}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "karpenter" {
  queue_url = aws_sqs_queue.karpenter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.karpenter.arn
      }
    ]
  })
}

# ── EventBridge rules for interruption handling ───────────────────────────────

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${local.name_prefix}-karpenter-spot-interruption"
  description = "Karpenter: EC2 Spot interruption notifications"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter.arn
}

# ── Karpenter controller IRSA role ───────────────────────────────────────────

resource "aws_iam_role" "karpenter" {
  name = "${local.name_prefix}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:karpenter:karpenter"
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "karpenter" {
  name = "${local.name_prefix}-karpenter-policy"
  role = aws_iam_role.karpenter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeImages",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeFleets",
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2NodeProvisioning"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
        ]
        Resource = [
          "arn:aws:ec2:*:*:instance/*",
          "arn:aws:ec2:*:*:launch-template/*",
          "arn:aws:ec2:*:*:fleet/*",
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:network-interface/*",
          "arn:aws:ec2:*:*:subnet/*",
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:image/*",
        ]
      },
      {
        Sid    = "AllowPassRoleToNodes"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = var.node_role_arn
      },
      {
        Sid    = "AllowSQSInterruptionQueue"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.karpenter.arn
      },
      {
        Sid    = "AllowEKSClusterAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
        ]
        Resource = "arn:aws:eks:*:*:cluster/${var.cluster_name}"
      },
    ]
  })
}

# ── Instance profile for Karpenter-launched nodes ────────────────────────────

resource "aws_iam_instance_profile" "karpenter" {
  name = "${local.name_prefix}-karpenter-node-profile"
  role = element(split("/", var.node_role_arn), length(split("/", var.node_role_arn)) - 1)

  tags = local.common_tags
}
