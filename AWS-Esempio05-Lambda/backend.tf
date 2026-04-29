terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio05Lambda/terraform.tfstate"
    region = "eu-central-1"
  }
}
