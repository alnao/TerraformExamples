variable "docker_image_name" {
  description = "Nome dell'immagine Docker da utilizzare"
  type        = string
  default     = "nginx"
}

variable "deployment_name" {
  description = "Nome del deployment Kubernetes"
  type        = string
  default     = "nginx-deployment"
}

variable "service_name" {
  description = "Nome del service Kubernetes"
  type        = string
  default     = "nginx-service"
}

variable "configmap_name" {
  description = "Nome della ConfigMap per i file HTML"
  type        = string
  default     = "nginx-html"
}

variable "external_port" {
  description = "Porta del service Kubernetes"
  type        = number
  default     = 80
}

variable "internal_port" {
  description = "Porta interna del container"
  type        = number
  default     = 80
}

variable "node_port" {
  description = "NodePort per accesso esterno (30000-32767)"
  type        = number
  default     = 30080
}

variable "replicas" {
  description = "Numero di repliche del deployment"
  type        = number
  default     = 1
}

variable "html_directory" {
  description = "Directory locale contenente i file HTML da servire"
  type        = string
  default     = "html"
}

variable "namespace" {
  description = "Namespace Kubernetes dove deployare le risorse"
  type        = string
  default     = "default"
}
