data "aws_caller_identity" "current" {}

locals {
  tags                        = { project = var.project_name, team = var.team_name, env = var.environment, owner = var.owner }
  backup_bucket_name          = coalesce(var.backup_bucket_name, "cybershield-backups-${data.aws_caller_identity.current.account_id}-${var.aws_region}")
  recovery_backup_bucket_name = coalesce(var.recovery_backup_bucket_name, "cybershield-backups-${data.aws_caller_identity.current.account_id}-${var.recovery_region}")
}

data "aws_availability_zones" "available" {
  count = var.enable_compute ? 1 : 0
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  count       = var.enable_compute ? 1 : 0
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
  tags   = local.tags
  count  = var.enable_compute ? 1 : 0
  source = "../../modules/network"

  name_prefix        = var.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = coalesce(var.availability_zone, data.aws_availability_zones.available[0].names[0])
  allowed_http_cidrs = var.allowed_http_cidrs
}

module "storage" {
  tags   = local.tags
  source = "../../modules/storage"

  bucket_name                        = local.backup_bucket_name
  current_version_expiration_days    = var.backup_retention_days
  force_destroy                      = false
  noncurrent_version_expiration_days = var.backup_noncurrent_version_expiration_days
}

module "iam" {
  permissions_boundary_arn = var.workload_permissions_boundary_arn
  tags                     = local.tags
  count                    = var.enable_compute && var.precreated_instance_profile_name == null ? 1 : 0
  source                   = "../../modules/iam"

  name_prefix        = var.name_prefix
  backup_bucket_arn  = module.storage.bucket_arn
  restore_bucket_arn = var.restore_manifest_uri == null ? null : "arn:aws:s3:::${split("/", var.restore_manifest_uri)[2]}"
  log_group_arn      = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/cybershield/${var.name_prefix}/application:*"
}

module "replication" {
  permissions_boundary_arn = var.workload_permissions_boundary_arn
  tags                     = local.tags
  count                    = var.enable_replication ? 1 : 0
  source                   = "../../modules/replication"

  name_prefix            = var.name_prefix
  source_bucket_name     = module.storage.bucket_name
  destination_bucket_arn = "arn:aws:s3:::${local.recovery_backup_bucket_name}"

  # Wait for source versioning and encryption, not just bucket creation.
  depends_on = [module.storage]
}

module "compute" {
  tags   = local.tags
  count  = var.enable_compute ? 1 : 0
  source = "../../modules/compute"

  name_prefix                 = var.name_prefix
  ami_id                      = data.aws_ami.amazon_linux_2023[0].id
  instance_type               = var.instance_type
  subnet_id                   = module.network[0].public_subnet_id
  security_group_ids          = [module.network[0].app_security_group_id]
  iam_instance_profile_name   = coalesce(var.precreated_instance_profile_name, try(module.iam[0].instance_profile_name, null))
  associate_public_ip_address = var.associate_public_ip_address
  root_volume_size            = var.root_volume_size
  enable_detailed_monitoring  = var.enable_detailed_monitoring
  user_data_base64 = base64gzip(templatefile("${path.module}/templates/user-data.sh.tftpl", {
    aws_region           = var.aws_region
    log_group_name       = "/cybershield/${var.name_prefix}/application"
    restore_manifest_uri = coalesce(var.restore_manifest_uri, "none")
    backup_s3_prefix     = "s3://${module.storage.bucket_name}/postgres"
    app_files = {
      for filename in ["compose.yaml", "Dockerfile", "requirements.txt", "database/init.sql", "src/app.py", "src/templates/index.html", "scripts/database.py", "systemd/cybershield-backup.service", "systemd/cybershield-backup.timer"] :
      filename => base64gzip(file("${path.module}/../../../app/${filename}"))
    }
  }))

  # First-boot backup needs bucket settings, IAM policies and Internet routing.
  depends_on = [module.storage, module.iam, module.network, module.replication]
}

module "monitoring" {
  tags   = local.tags
  count  = var.enable_compute ? 1 : 0
  source = "../../modules/monitoring"

  name_prefix                  = var.name_prefix
  instance_id                  = module.compute[0].instance_id
  notification_email_addresses = var.notification_email_addresses
  log_retention_days           = var.log_retention_days
  cpu_threshold_percent        = var.cpu_threshold_percent
  cpu_evaluation_periods       = var.cpu_evaluation_periods
}
