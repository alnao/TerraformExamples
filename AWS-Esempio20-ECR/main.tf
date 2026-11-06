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
      Project = lookup(var.tags, "Project", "Development.aws.terraform20-ECR")
    }
  )

  repository_name = var.repository_name != "" ? var.repository_name : "${var.project_name}-pathsgames"
  image_uri       = "${aws_ecr_repository.pathsgames.repository_url}:${var.image_tag}"
  log_group_name  = "/alnao/${var.project_name}/pathsgames"
  ssm_prefix      = "/alnao/${var.project_name}"
}

data "aws_caller_identity" "current" {}

# ====================================
# RETE
# Se non viene indicata una VPC si usa quella di default dell'account,
# cosi' l'esempio e' eseguibile senza altri prerequisiti.
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

# Ricerca dell'AMI piu' recente di Amazon Linux 2023 standard.
# Il filtro "al2023-ami-*" troverebbe anche le varianti ecs e minimal
# (l'ECS-optimized ha uno snapshot da 30 GB): qui serve la versione base.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
