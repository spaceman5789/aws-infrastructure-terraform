module "vpc" {
  source = "./modules/vpc"

  vpc_cidr                 = "10.0.0.0/16"
  project_name             = "terraform"
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]
  availability_zones       = ["eu-north-1a", "eu-north-1b"]
}