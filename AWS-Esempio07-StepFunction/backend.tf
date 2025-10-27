terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio07StepFunction/terraform.tfstate"
    region = "eu-central-1"
  }
}
