terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio21ECS/terraform.tfstate"
    region = "eu-central-1"
  }
}
