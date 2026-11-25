output "instance_id" {
  description = "ID of the EC2 application instance."
  value       = aws_instance.app.id
}

output "instance_arn" {
  description = "ARN of the EC2 application instance."
  value       = aws_instance.app.arn
}

output "private_ip" {
  description = "Private IPv4 address assigned to the EC2 instance."
  value       = aws_instance.app.private_ip
}

output "public_ip" {
  description = "Public IPv4 address assigned to the EC2 instance, if enabled."
  value       = aws_instance.app.public_ip
}

output "public_dns" {
  description = "Public DNS name assigned to the EC2 instance, if available."
  value       = aws_instance.app.public_dns
}

output "availability_zone" {
  description = "Availability Zone in which the EC2 instance is running."
  value       = aws_instance.app.availability_zone
}

output "primary_network_interface_id" {
  description = "ID of the primary network interface attached to the EC2 instance."
  value       = aws_instance.app.primary_network_interface_id
}
