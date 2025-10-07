terraform {
    required_providers {
        docker = {
            source  = "kreuzwerker/docker"
            version = "~> 3.0.1"
        }
    }
}

provider "docker" {}

resource "docker_image" "nginx" {
    name         = var.docker_image_name
    keep_locally = var.keep_image_locally
}

resource "docker_container" "nginx" {
    image = docker_image.nginx.image_id
    name  = var.container_name

    ports {
        internal = var.internal_port
        external = var.external_port
    }

    volumes {
        host_path      = abspath("${path.module}/${var.html_directory}")
        container_path = "/usr/share/nginx/html"
        read_only      = true
    }
}