locals {
  role_name             = "${var.name_prefix}-ec2-role"
  instance_profile_name = "${var.name_prefix}-ec2-profile"
  backup_policy_name    = "${var.name_prefix}-backup-policy"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "AllowEC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = local.role_name
  description        = "Role assumed by the CyberShield Academy EC2 application instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Component = "IAM"
    Name      = local.role_name
    Purpose   = "EC2InstanceRole"
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = local.instance_profile_name
  role = aws_iam_role.ec2.name

  tags = merge(var.tags, {
    Component = "IAM"
    Name      = local.instance_profile_name
    Purpose   = "EC2InstanceProfile"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "backup_access" {
  statement {
    sid    = "AllowBackupBucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]
    resources = [var.backup_bucket_arn]
  }

  statement {
    sid    = "AllowBackupObjectAccess"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]
    resources = ["${var.backup_bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "backup_access" {
  name        = local.backup_policy_name
  description = "Allows the EC2 application instance to upload and restore PostgreSQL backups"
  policy      = data.aws_iam_policy_document.backup_access.json

  tags = merge(var.tags, {
    Component = "IAM"
    Name      = local.backup_policy_name
    Purpose   = "S3BackupAccess"
  })
}

resource "aws_iam_role_policy_attachment" "backup_access" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.backup_access.arn
}
