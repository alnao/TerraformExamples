terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# ConfigMap per il file HTML
resource "kubernetes_config_map" "nginx_html" {
  metadata {
    name = var.configmap_name
  }

  data = {
    "index.html" = file(abspath("${path.module}/${var.html_directory}/index.html"))
  }
}

# Deployment (equivalente al container Docker)
resource "kubernetes_deployment" "nginx" {
  metadata {
    name = var.deployment_name
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image = var.docker_image_name
          name  = "nginx"

          port {
            container_port = var.internal_port
          }

          volume_mount {
            name       = "html-volume"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }
        }

        volume {
          name = "html-volume"
          config_map {
            name = kubernetes_config_map.nginx_html.metadata[0].name
          }
        }
      }
    }
  }
}

# Service per esporre il deployment
resource "kubernetes_service" "nginx" {
  metadata {
    name = var.service_name
  }

  spec {
    selector = {
      app = kubernetes_deployment.nginx.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = var.external_port
      target_port = var.internal_port
      node_port   = var.node_port
    }

    type = "NodePort"
  }
}