resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.iam_instance_profile_name
  associate_public_ip_address = var.associate_public_ip_address
  monitoring                  = var.enable_detailed_monitoring
  user_data                   = var.user_data
  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Component = "Compute"
    Name      = "${var.name_prefix}-app"
    Purpose   = "ApplicationAndDatabase"
  })

  volume_tags = merge(var.tags, {
    Component = "Compute"
    Name      = "${var.name_prefix}-root"
    Purpose   = "EncryptedRootVolume"
  })
}
