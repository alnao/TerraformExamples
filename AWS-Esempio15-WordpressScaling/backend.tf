terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio15WordpressScaling/terraform.tfstate"
    region = "eu-central-1"
  }
}
