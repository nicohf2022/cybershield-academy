locals {
  component_tags = {
    Component = "Network"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, local.component_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.tags, local.component_tags, {
    Name = "${var.name_prefix}-public-subnet"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, local.component_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, local.component_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name_prefix            = "${var.name_prefix}-app-"
  description            = "Controls network traffic for the application"
  vpc_id                 = aws_vpc.this.id
  revoke_rules_on_delete = true

  tags = merge(var.tags, local.component_tags, {
    Name = "${var.name_prefix}-app-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  for_each = toset(var.allowed_http_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "Allow HTTP traffic from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80

  tags = merge(var.tags, local.component_tags, {
    Name = "${var.name_prefix}-app-http-ingress"
  })
}

# Bootstrap needs HTTPS to AWS, GitHub and container registries with dynamic IPs.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "app_ipv4" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS APIs, package sources and container registries"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = merge(var.tags, local.component_tags, {
    Name = "${var.name_prefix}-app-ipv4-egress"
  })
}
