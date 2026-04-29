terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio07StepFunction/terraform.tfstate"
    region = "eu-central-1"
  }
}
