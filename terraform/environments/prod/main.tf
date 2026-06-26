terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project             = "petclinic"
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "ecr" {
  source = "../../modules/ecr"

  project      = "petclinic"
  environment  = var.environment
  service_names = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "visits-service",
    "vets-service",
    "genai-service",
    "admin-server",
  ]
}

module "eks" {
  source = "../../modules/eks"

  project              = "petclinic"
  environment          = var.environment
  subnet_ids           = module.vpc.public_subnet_ids
  cluster_sg_id        = module.vpc.eks_cluster_sg_id
  node_sg_id           = module.vpc.eks_node_sg_id
  node_instance_types  = ["t4g.small"]
  node_ami_type        = "AL2_ARM_64"
  node_min_size        = 2
  node_max_size        = 4
  node_desired_size    = 2
}

module "rds" {
  source = "../../modules/rds"

  project               = "petclinic"
  environment           = var.environment
  subnet_ids            = module.vpc.public_subnet_ids
  security_group_id     = module.vpc.rds_sg_id
  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 20
  multi_az              = false
  skip_final_snapshot   = false
  deletion_protection   = true
}

module "secrets" {
  source = "../../modules/secrets"

  project        = "petclinic"
  environment    = var.environment
  openai_api_key = var.openai_api_key
}
