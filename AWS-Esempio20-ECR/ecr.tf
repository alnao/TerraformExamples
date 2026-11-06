# ====================================
# REPOSITORY ECR
# Registry privato dove viene copiata l'immagine pubblica di Docker Hub.
# force_delete permette a "terraform destroy" di cancellare il repository
# anche se contiene immagini.
# ====================================

resource "aws_ecr_repository" "pathsgames" {
  name                 = local.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, { Name = "aws-esempio20.ecr" })
}

# Tiene solo le ultime N immagini con tag e cancella quelle senza tag dopo un giorno.
# Nota: la lifecycle policy non e' una risorsa taggabile (eredita il repository).
resource "aws_ecr_lifecycle_policy" "pathsgames" {
  repository = aws_ecr_repository.pathsgames.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Cancella le immagini senza tag dopo 1 giorno"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Mantiene solo le ultime ${var.max_image_count} immagini"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ====================================
# COPIA DELL'IMMAGINE DA DOCKER HUB A ECR
# Eseguita sul pc che lancia terraform: servono Docker e la AWS CLI.
# terraform_data non e' una risorsa AWS, quindi non ha tag.
# Viene rieseguita se cambiano immagine sorgente, tag o repository.
# ====================================

resource "terraform_data" "push_image" {
  triggers_replace = [
    var.source_image,
    var.image_tag,
    var.image_platform,
    aws_ecr_repository.pathsgames.repository_url,
  ]

  provisioner "local-exec" {
    command = "${path.module}/push_image.sh"
    environment = {
      SOURCE_IMAGE   = "${var.source_image}:${var.image_tag}"
      TARGET_IMAGE   = local.image_uri
      REGISTRY       = split("/", aws_ecr_repository.pathsgames.repository_url)[0]
      AWS_REGION     = var.region
      IMAGE_PLATFORM = var.image_platform
    }
  }
}
