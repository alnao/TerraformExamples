terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio20ECR/terraform.tfstate"
    region = "eu-central-1"
  }
}
