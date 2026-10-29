locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      Deployed_By   = "Terraform"
      shutdown = "true"
      startup = "true"
    }
  )

  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_name             = "${var.project_name}-vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway   = false
  environment          = var.environment

  tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security_groups"

  vpc_id       = module.vpc.vpc_id
  environment  = var.environment
  project_name = var.project_name
  jenkins_port = 8080

  tags = local.common_tags
}

# Key Pair Module
module "key_pair" {
  source = "./modules/key_pair"

  key_name    = var.key_pair_name
  environment = var.environment

  tags = local.common_tags
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  bucket_name = local.s3_bucket_name
  environment = var.environment

  tags = local.common_tags
}

# EC2 Module - Docker Installation
module "ec2_docker" {
  source = "./modules/ec2-docker"

  instance_name          = "${var.project_name}-docker"
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnet_ids[1]
  vpc_security_group_ids = [module.security_groups.jenkins_sg_id]
  key_name               = module.key_pair.key_pair_name
  associate_public_ip    = var.enable_public_ip
  s3_bucket_name         = module.s3.bucket_name
  environment            = var.environment
  count                   = var.instance_count

  tags = merge(
    local.common_tags,
    {
      DeploymentType = "Docker Container"
    }
  )

  depends_on = [module.key_pair, module.s3]
}
