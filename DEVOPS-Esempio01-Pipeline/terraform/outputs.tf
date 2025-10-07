output "namespace" {
  description = "Nome del namespace creato"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "deployment_name" {
  description = "Nome del deployment"
  value       = kubernetes_deployment.app.metadata[0].name
}

output "service_name" {
  description = "Nome del service"
  value       = kubernetes_service.app.metadata[0].name
}

output "service_cluster_ip" {
  description = "Cluster IP del service"
  value       = kubernetes_service.app.spec[0].cluster_ip
}

output "app_url" {
  description = "URL dell'applicazione"
  value = var.enable_ingress ? "http://${var.ingress_host}" : "http://localhost:8080 (use kubectl port-forward)"
}

output "ingress_hostname" {
  description = "Hostname dell'Ingress"
  value       = var.enable_ingress ? kubernetes_ingress_v1.app[0].spec[0].rule[0].host : null
}

output "current_version" {
  description = "Versione corrente deployata"
  value       = var.image_tag
}

output "replicas" {
  description = "Numero di repliche configurate"
  value       = var.replicas
}

output "hpa_enabled" {
  description = "Stato HPA"
  value       = var.enable_hpa
}

output "resource_limits" {
  description = "Limiti di risorse configurati"
  value = {
    cpu_request    = var.cpu_request
    memory_request = var.memory_request
    cpu_limit      = var.cpu_limit
    memory_limit   = var.memory_limit
  }
}

output "environment_info" {
  description = "Informazioni ambiente"
  value = {
    environment = var.environment
    namespace   = var.namespace
    app_name    = var.app_name
  }
}
