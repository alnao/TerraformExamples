terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio13SQSSNS/terraform.tfstate"
    region = "eu-central-1"
  }
}
