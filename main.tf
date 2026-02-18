module "network" {
  source               = "./modules/vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnets_cidr
  private_subnet_cidr  = var.private_subnets_cidr
}

module "security" {
  source    = "./modules/security"
  vpc_id    = module.network.vpc_id
  my_ip     = var.my_ip # Access to Bastion
}

module "compute" {
  source                 = "./modules/compute"
  vpc_id = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids # Assuming ALB is in public subnets
  private_subnet_ids      = module.network.private_subnet_ids # Assuming compute instances are in private subnets
  bastion_sg_id          = module.security.bastion_sg_id
  monitoring_sg_id       = module.security.monitoring_sg_id
  alb_sg_id              = module.security.alb_sg_id
  db_sg_id                = module.security.db_sg_id
  llm_sg_id              = module.security.llm_sg_id
  key_name               = var.key_name
}


