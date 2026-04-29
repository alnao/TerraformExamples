terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio10RDS/terraform.tfstate"
    region = "eu-central-1"
  }
}
