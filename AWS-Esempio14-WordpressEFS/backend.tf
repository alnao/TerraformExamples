terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio14WordpressEFS/terraform.tfstate"
    region = "eu-central-1"
  }
}
