variable "docker_image_name" {
  description = "Nome dell'immagine Docker da utilizzare"
  type        = string
  default     = "nginx"
}

variable "container_name" {
  description = "Nome del container Docker"
  type        = string
  default     = "tutorial"
}

variable "external_port" {
  description = "Porta esterna esposta per il container"
  type        = number
  default     = 8001
}

variable "internal_port" {
  description = "Porta interna del container"
  type        = number
  default     = 80
}

variable "keep_image_locally" {
  description = "Mantieni l'immagine Docker localmente dopo destroy"
  type        = bool
  default     = false
}

variable "html_directory" {
  description = "Directory locale contenente i file HTML da servire"
  type        = string
  default     = "html"
}
