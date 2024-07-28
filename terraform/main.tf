provider "aws" {
  region  = "us-west-2"  # Change as needed
  profile = var.aws_profile
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_instances" "instances" {
  filter {
    name   = "tag:Name"
    values = var.instance_names
  }
}

# Convert list of instance IDs to a map with indices
locals {
  instance_map = { for idx, id in data.aws_instances.instances.ids : id => idx }
}

# Create IAM role for EC2 backups
resource "aws_iam_role" "ec2_backup_role" {
  count = length(data.aws_instances.instances.ids)
  name  = "ec2-backup-role-${element(var.instance_names, count.index)}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Create IAM role for EBS backups
resource "aws_iam_role" "ebs_backup_role" {
  count = length(data.aws_instances.instances.ids)
  name  = "ebs-backup-role-${element(var.instance_names, count.index)}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for EC2 backups
resource "aws_iam_role_policy_attachment" "ec2_backup_policy_attachment" {
  count = length(data.aws_instances.instances.ids)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role      = aws_iam_role.ec2_backup_role[count.index].name
}

# IAM Policy for EBS backups
resource "aws_iam_role_policy_attachment" "ebs_backup_policy_attachment" {
  count = length(data.aws_instances.instances.ids)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role      = aws_iam_role.ebs_backup_role[count.index].name
}

resource "aws_backup_vault" "ec2_backup_vault" {
  count = length(data.aws_instances.instances.ids)
  name  = "ec2-backup-vault-${element(var.instance_names, count.index)}"
}

resource "aws_backup_vault" "ebs_backup_vault" {
  count = length(data.aws_instances.instances.ids)
  name  = "ebs-backup-vault-${element(var.instance_names, count.index)}"
}

resource "aws_backup_plan" "ec2_backup_plan" {
  count = length(data.aws_instances.instances.ids)
  name  = "ec2-backup-plan-${element(var.instance_names, count.index)}"

  rule {
    rule_name         = "ec2-backup-rule-${element(var.instance_names, count.index)}"
    target_vault_name = aws_backup_vault.ec2_backup_vault[count.index].name
    schedule          = "cron(0 0 1 * ? *)"  # Monthly
    start_window      = 60
    completion_window = 180

    lifecycle {
      cold_storage_after = 30
      delete_after       = 180
    }

    recovery_point_tags = {
      "Name" = "ec2-backup-${element(var.instance_names, count.index)}"
    }
  }
}

resource "aws_backup_plan" "ebs_backup_plan" {
  count = length(data.aws_instances.instances.ids)
  name  = "ebs-backup-plan-${element(var.instance_names, count.index)}"

  rule {
    rule_name         = "ebs-backup-rule-${element(var.instance_names, count.index)}"
    target_vault_name = aws_backup_vault.ebs_backup_vault[count.index].name
    schedule          = "cron(30 0 ? * * *)"  # Daily
    start_window      = 60
    completion_window = 180

    lifecycle {
      cold_storage_after = 7
      delete_after       = 98
    }

    recovery_point_tags = {
      "Name" = "ebs-backup-${element(var.instance_names, count.index)}"
    }
  }
}

data "aws_ebs_volumes" "attached_volumes" {
  for_each = local.instance_map
  filter {
    name   = "attachment.instance-id"
    values = [each.key]
  }
}

resource "aws_backup_selection" "ec2_backup_selection" {
  count = length(data.aws_instances.instances.ids)

  plan_id    = aws_backup_plan.ec2_backup_plan[count.index].id
  name       = "ec2-backup-selection-${element(var.instance_names, count.index)}"
  iam_role_arn = aws_iam_role.ec2_backup_role[count.index].arn
  resources  = [
    for inst in data.aws_instances.instances.ids : "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${inst}"
  ]
}

resource "aws_backup_selection" "ebs_backup_selection" {
  for_each = local.instance_map

  plan_id    = aws_backup_plan.ebs_backup_plan[each.value].id
  name       = "ebs-backup-selection-${each.key}"
  iam_role_arn = aws_iam_role.ebs_backup_role[each.value].arn
  resources  = [
    for vol in data.aws_ebs_volumes.attached_volumes[each.key].ids : "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/${vol}"
  ]
}
