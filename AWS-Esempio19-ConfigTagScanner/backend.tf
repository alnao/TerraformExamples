terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio19ConfigTagScanner/terraform.tfstate"
    region = "eu-central-1"
  }
}
