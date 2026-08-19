output "wordpress_url" {
  description = "URL pubblico di WordPress via ALB"
  value       = var.enable_https ? "https://${aws_lb.wordpress.dns_name}" : "http://${aws_lb.wordpress.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name del load balancer"
  value       = aws_lb.wordpress.dns_name
}

output "bastion_public_ip" {
  description = "IP pubblico della bastion EC2"
  value       = aws_eip.bastion.public_ip
}

output "autoscaling_group_name" {
  description = "Nome dell'Auto Scaling Group"
  value       = aws_autoscaling_group.wordpress.name
}

output "efs_id" {
  description = "ID del file system EFS"
  value       = aws_efs_file_system.wordpress.id
}

output "rds_endpoint" {
  description = "Endpoint del database RDS"
  value       = aws_db_instance.wordpress.address
}

output "lambda_scale_up_name" {
  description = "Nome lambda di incremento capacita"
  value       = aws_lambda_function.scale_up.function_name
}

output "lambda_scale_down_name" {
  description = "Nome lambda di riduzione capacita"
  value       = aws_lambda_function.scale_down.function_name
}
