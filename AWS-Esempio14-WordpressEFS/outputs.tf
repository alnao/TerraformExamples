output "elastic_ip" {
  description = "Elastic IP pubblico della EC2"
  value       = aws_eip.wordpress.public_ip
}

output "wordpress_url" {
  description = "URL pubblico di WordPress"
  value       = "http://${aws_eip.wordpress.public_ip}"
}

output "ec2_instance_id" {
  description = "ID dell'istanza EC2"
  value       = aws_instance.wordpress.id
}

output "efs_id" {
  description = "ID del file system EFS"
  value       = aws_efs_file_system.wordpress.id
}

output "rds_endpoint" {
  description = "Endpoint del database RDS"
  value       = aws_db_instance.wordpress.address
}

output "rds_db_name" {
  description = "Nome database WordPress"
  value       = aws_db_instance.wordpress.db_name
}
