variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}


variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "terraform"
}


variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}


variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}


variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets"
  type = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default = ["eu-north-1a", "eu-north-1b"]
}