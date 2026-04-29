terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio11LambdaApplicationS3Utils/terraform.tfstate"
    region = "eu-central-1"
  }
}
