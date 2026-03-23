terraform {
  backend "s3" {
    bucket         = "terraform-state-denis-2026"
    key            = "prod/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  } 
}