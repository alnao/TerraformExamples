output "ecr_repository_name" {
  description = "Nome del repository ECR (da usare nell'esempio 21)"
  value       = aws_ecr_repository.pathsgames.name
}

output "ecr_repository_url" {
  description = "URL del repository ECR"
  value       = aws_ecr_repository.pathsgames.repository_url
}

output "image_tag" {
  description = "Tag dell'immagine copiata su ECR ed eseguita"
  value       = var.image_tag
}

output "image_uri" {
  description = "Immagine completa eseguita dall'istanza"
  value       = local.image_uri
}

output "instance_id" {
  description = "ID dell'istanza EC2 (per collegarsi: aws ssm start-session --target <id>)"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "IP pubblico dell'istanza EC2"
  value       = aws_instance.web.public_ip
}

output "url_status" {
  description = "Endpoint di stato dell'applicazione"
  value       = "http://${aws_instance.web.public_ip}${var.host_port == 80 ? "" : ":${var.host_port}"}/api/echo/status"
}

output "url_stories" {
  description = "Elenco pubblico delle storie"
  value       = "http://${aws_instance.web.public_ip}${var.host_port == 80 ? "" : ":${var.host_port}"}/api/stories"
}

output "log_group_name" {
  description = "Log group CloudWatch con i log dei container"
  value       = aws_cloudwatch_log_group.containers.name
}
