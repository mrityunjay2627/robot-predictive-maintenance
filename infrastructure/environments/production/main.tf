module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  # VPC Naming and IP Range
  name = "robot-vpc"
  cidr = "10.0.0.0/16"

  # Subnet Configuration across 3 Availability Zones
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # NAT Gateway for private subnets to access the internet
  enable_nat_gateway = true
  single_nat_gateway = true # For cost savings in a single dev environment

  # Standard tags to apply to all resources
  tags = {
    Project     = "robot-predictive-maintenance"
    ManagedBy   = "Terraform"
  }
}