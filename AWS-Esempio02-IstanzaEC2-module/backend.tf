terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio02IstanzaEC2Module/terraform.tfstate"
    region = "eu-central-1"
  }
}
