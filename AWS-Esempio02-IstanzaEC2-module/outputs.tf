# Outputs dal modulo EC2
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2_instance.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = module.ec2_instance.arn
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2_instance.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = module.ec2_instance.public_dns
}

output "instance_private_dns" {
  description = "Private DNS name of the EC2 instance"
  value       = module.ec2_instance.private_dns
}

output "instance_state" {
  description = "State of the EC2 instance"
  value       = module.ec2_instance.instance_state
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ec2_sg.id
}

output "security_group_name" {
  description = "Name of the security group"
  value       = aws_security_group.ec2_sg.name
}

output "elastic_ip" {
  description = "Elastic IP address (if created)"
  value       = var.create_eip ? aws_eip.ec2_eip[0].public_ip : null
}

output "elastic_ip_allocation_id" {
  description = "Elastic IP allocation ID (if created)"
  value       = var.create_eip ? aws_eip.ec2_eip[0].allocation_id : null
}

output "ssh_connection_string" {
  description = "SSH connection string"
  value       = var.key_name != "" ? "ssh -i <path-to-key> ec2-user@${var.create_eip ? aws_eip.ec2_eip[0].public_ip : module.ec2_instance.public_ip}" : "No SSH key configured"
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = module.ec2_instance.ami
}
