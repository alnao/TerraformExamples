terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio16RekognitionImageDetector/terraform.tfstate"
    region = "eu-central-1"
  }
}
