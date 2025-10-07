variable "app_name" {
  description = "Nome dell'applicazione"
  type        = string
  default     = "devops-app"
}

variable "environment" {
  description = "Ambiente di deploy (dev, staging, prod)"
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes"
  type        = string
}

variable "image_repository" {
  description = "Repository dell'immagine Docker"
  type        = string
  default     = "registry.gitlab.com/alnao/devops-app"
}

variable "image_tag" {
  description = "Tag dell'immagine Docker"
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "Numero di repliche del deployment"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Porta del container"
  type        = number
  default     = 80
}

variable "service_type" {
  description = "Tipo di service Kubernetes"
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "Service type deve essere ClusterIP, NodePort o LoadBalancer."
  }
}

variable "cpu_request" {
  description = "CPU request per il container"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request per il container"
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit per il container"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit per il container"
  type        = string
  default     = "512Mi"
}

variable "enable_ingress" {
  description = "Abilita Ingress per accesso esterno"
  type        = bool
  default     = false
}

variable "ingress_host" {
  description = "Hostname per l'Ingress"
  type        = string
  default     = "app.local"
}

variable "enable_hpa" {
  description = "Abilita HorizontalPodAutoscaler"
  type        = bool
  default     = false
}

variable "min_replicas" {
  description = "Numero minimo di repliche per HPA"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Numero massimo di repliche per HPA"
  type        = number
  default     = 10
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization per HPA (%)"
  type        = number
  default     = 70
}

variable "target_memory_utilization" {
  description = "Target memory utilization per HPA (%)"
  type        = number
  default     = 80
}

variable "debug_mode" {
  description = "Abilita modalità debug"
  type        = string
  default     = "false"
}

variable "api_url" {
  description = "URL dell'API backend"
  type        = string
  default     = "https://api.example.com"
}

variable "database_password" {
  description = "Password del database"
  type        = string
  sensitive   = true
  default     = "change-me-in-production"
}

variable "api_key" {
  description = "API Key per servizi esterni"
  type        = string
  sensitive   = true
  default     = "your-api-key-here"
}

variable "tags" {
  description = "Tag da applicare alle risorse"
  type        = map(string)
  default     = {
    ManagedBy = "terraform"
    Project   = "devops-pipeline"
  }
}
