terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio02IstanzaEC2/terraform.tfstate"
    region = "eu-central-1"
  }
}
