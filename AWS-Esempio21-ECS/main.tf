terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# I tag comuni sono messi esplicitamente su ogni risorsa; default_tags e' una
# rete di sicurezza: qualunque risorsa taggabile aggiunta in futuro li riceve.
provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      Project = lookup(var.tags, "Project", "Development.aws.terraform21-ECS")
    }
  )

  # Immagine: quella copiata su ECR dall'esempio 20, oppure una indicata a mano.
  # Da ECR si usa il digest (repository@sha256:...) invece del tag: se il tag
  # viene sovrascritto con un'immagine nuova cambia il digest, quindi cambia
  # la task definition e ECS fa un nuovo deploy.
  use_ecr   = var.container_image == ""
  image_uri = local.use_ecr ? "${data.aws_ecr_repository.pathsgames[0].repository_url}@${data.aws_ecr_image.pathsgames[0].image_digest}" : var.container_image

  log_group_name = "/alnao/${var.project_name}/pathsgames"
  ssm_prefix     = "/alnao/${var.project_name}"
  app_port       = 8042
}

# ====================================
# IMMAGINE DELL'ESEMPIO 20
# Il repository ECR e l'immagine devono esistere: se mancano, il plan
# fallisce subito invece di avere un servizio che non parte.
# Con image_tag vuoto si prende l'immagine piu' recente del repository,
# cioe' l'ultima versione copiata dall'esempio 20: la versione si decide
# in un solo posto (image_tag dell'esempio 20).
# ====================================

data "aws_ecr_repository" "pathsgames" {
  count = local.use_ecr ? 1 : 0
  name  = var.ecr_repository_name
}

data "aws_ecr_image" "pathsgames" {
  count           = local.use_ecr ? 1 : 0
  repository_name = data.aws_ecr_repository.pathsgames[0].name
  image_tag       = var.image_tag != "" ? var.image_tag : null
  most_recent     = var.image_tag == "" ? true : null
}

# ====================================
# RETE
# VPC di default (o quella indicata) e le sue subnet pubbliche: ALB e task
# stanno nelle stesse subnet, i task hanno un IP pubblico per scaricare
# l'immagine senza NAT Gateway (che costerebbe piu' dell'esempio intero).
# ====================================

data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id != "" ? null : true
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

locals {
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.selected.ids
}
