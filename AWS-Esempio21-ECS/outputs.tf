output "image_uri" {
  description = "Immagine eseguita dal servizio"
  value       = local.image_uri
}

output "image_tags" {
  description = "Tag dell'immagine ECR eseguita (vuoto se si usa container_image)"
  value       = local.use_ecr ? data.aws_ecr_image.pathsgames[0].image_tags : []
}

output "image_digest" {
  description = "Digest dell'immagine su ECR (vuoto se si usa container_image)"
  value       = local.use_ecr ? data.aws_ecr_image.pathsgames[0].image_digest : ""
}

output "alb_dns_name" {
  description = "DNS pubblico dell'Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "url_status" {
  description = "Endpoint di stato dell'applicazione"
  value       = "http://${aws_lb.main.dns_name}/api/echo/status"
}

output "url_stories" {
  description = "Elenco pubblico delle storie"
  value       = "http://${aws_lb.main.dns_name}/api/stories"
}

output "cluster_name" {
  description = "Nome del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Nome del service ECS"
  value       = aws_ecs_service.app.name
}

output "log_group_name" {
  description = "Log group CloudWatch con i log dei container"
  value       = aws_cloudwatch_log_group.containers.name
}
