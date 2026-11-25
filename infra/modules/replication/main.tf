locals {
  source_bucket_arn = "arn:aws:s3:::${var.source_bucket_name}"
}

resource "aws_iam_role" "replication" {
  permissions_boundary = var.permissions_boundary_arn
  name                 = "${var.name_prefix}-s3-replication"
  description          = "S3 service role for one-way PostgreSQL backup replication."
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-s3-replication"
    Component = "Replication"
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "${var.name_prefix}-s3-replication"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSourceReplicationConfiguration"
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = local.source_bucket_arn
      },
      {
        Sid    = "ReadSourceBackupVersions"
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
        ]
        Resource = "${local.source_bucket_arn}/${var.object_prefix}*"
      },
      {
        Sid      = "WriteRecoveryReplicas"
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateTags"]
        Resource = "${var.destination_bucket_arn}/${var.object_prefix}*"
      },
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "backups" {
  bucket = var.source_bucket_name
  role   = aws_iam_role.replication.arn

  rule {
    id       = "postgres-backups-to-recovery"
    status   = "Enabled"
    priority = 1

    filter {
      prefix = var.object_prefix
    }

    # Keep recovery copies when a source object is deleted.
    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = var.destination_bucket_arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_iam_role_policy.replication]
}
