data "aws_caller_identity" "current" {}

locals {
  recovery_backup_bucket_name = coalesce(var.recovery_backup_bucket_name, "cybershield-backups-${data.aws_caller_identity.current.account_id}-${var.recovery_region}")
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix        = var.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
  allowed_http_cidrs = var.allowed_http_cidrs
}

module "storage" {
  source = "../../modules/storage"

  bucket_name                        = var.backup_bucket_name
  force_destroy                      = false
  noncurrent_version_expiration_days = var.backup_noncurrent_version_expiration_days
}

module "iam" {
  source = "../../modules/iam"

  name_prefix       = var.name_prefix
  backup_bucket_arn = module.storage.bucket_arn
}

module "replication" {
  source = "../../modules/replication"

  name_prefix            = var.name_prefix
  source_bucket_name     = module.storage.bucket_name
  destination_bucket_arn = "arn:aws:s3:::${local.recovery_backup_bucket_name}"

  # Wait for source versioning and encryption, not just bucket creation.
  depends_on = [module.storage]
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                 = var.name_prefix
  ami_id                      = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = module.network.public_subnet_id
  security_group_ids          = [module.network.app_security_group_id]
  iam_instance_profile_name   = module.iam.instance_profile_name
  associate_public_ip_address = var.associate_public_ip_address
  root_volume_size            = var.root_volume_size
  enable_detailed_monitoring  = var.enable_detailed_monitoring
  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    backup_s3_prefix = "s3://${module.storage.bucket_name}/postgres"
    app_files = {
      for filename in ["compose.yaml", "Dockerfile", "requirements.txt", "database/init.sql", "src/app.py", "src/templates/index.html", "scripts/database.py", "systemd/cybershield-backup.service", "systemd/cybershield-backup.timer"] :
      filename => base64gzip(file("${path.module}/../../../app/${filename}"))
    }
  })

  # First-boot backup needs bucket settings, IAM policies and Internet routing.
  depends_on = [module.storage, module.iam, module.network, module.replication]
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix                  = var.name_prefix
  instance_id                  = module.compute.instance_id
  notification_email_addresses = var.notification_email_addresses
  log_retention_days           = var.log_retention_days
  cpu_threshold_percent        = var.cpu_threshold_percent
  cpu_evaluation_periods       = var.cpu_evaluation_periods
}
