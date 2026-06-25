terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio12GlueJob/terraform.tfstate"
    region = "eu-central-1"
  }
}
