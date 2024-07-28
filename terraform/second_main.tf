# This code makes just 2 plans one for Ec2 and EBS
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

data "aws_ebs_volumes" "attached_volumes" {
  filter {
    name   = "attachment.instance-id"
    values = data.aws_instances.instances.ids
  }
}

# Define IAM role for backup plans
resource "aws_iam_role" "backup_role" {
  name = "backup-role"

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

resource "aws_iam_role_policy_attachment" "backup_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role      = aws_iam_role.backup_role.name
}

# Create Backup Vaults
resource "aws_backup_vault" "backup_vault" {
  name = "backup-vault"
}

# Create Backup Plans
resource "aws_backup_plan" "ec2_backup_plan" {
  name = "ec2-backup-plan"

  rule {
    rule_name         = "ec2-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 0 1 * ? *)"  # Monthly
    start_window      = 60
    completion_window = 180

    lifecycle {
      cold_storage_after = 30
      delete_after       = 180
    }

    recovery_point_tags = {
      "Name" = "ec2-backup"
    }
  }
}

resource "aws_backup_plan" "ebs_backup_plan" {
  name = "ebs-backup-plan"

  rule {
    rule_name         = "ebs-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 0 * * ? *)"  # Daily
    start_window      = 60
    completion_window = 180

    lifecycle {
      cold_storage_after = 7
      delete_after       = 98
    }

    recovery_point_tags = {
      "Name" = "ebs-backup"
    }
  }
}

# Create Backup Selections for EC2 and EBS
resource "aws_backup_selection" "ec2_backup_selection" {
  plan_id    = aws_backup_plan.ec2_backup_plan.id
  name       = "ec2-backup-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  resources  = [
    for inst in data.aws_instances.instances.ids : "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${inst}"
  ]
}

resource "aws_backup_selection" "ebs_backup_selection" {
  plan_id    = aws_backup_plan.ebs_backup_plan.id
  name       = "ebs-backup-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  resources  = [
    for vol in data.aws_ebs_volumes.attached_volumes.ids : "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/${vol}"
  ]
}
