output "vpc_id" {
  description = "ID of the VPC created by the network module."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "IPv4 CIDR block assigned to the public subnet."
  value       = aws_subnet.public.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = aws_internet_gateway.this.id
}

output "public_route_table_id" {
  description = "ID of the route table associated with the public subnet."
  value       = aws_route_table.public.id
}

output "app_security_group_id" {
  description = "ID of the Security Group assigned to the application."
  value       = aws_security_group.app.id
}
