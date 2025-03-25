data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}

module "blog_ysani_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.1.0"

  # Autoscaling group
  name = "blog-ysani-asg"

  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  vpc_zone_identifier       = module.blog_ysani_vpc.public_subnets
  security_groups           = [module.blog_ysani_sg.security_group_id]

  #template
  image_id          = data.aws_ami.app_ami.id
  instance_type     = var.instance_type

  traffic_source_attachments = {
    traffic_source = {
      traffic_source_identifier = module.module_alb.target_groups["ex-instance"].arn
      type                      = "elbv2"
    }
  }
}

module "module_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-ysani-alb2"
  vpc_id  = module.blog_ysani_vpc.vpc_id
  subnets = module.blog_ysani_vpc.public_subnets
  security_groups = [module.blog_ysani_sg.security_group_id]

  listeners = {
    ex-http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ex-instance"
      }
    }
  }

  target_groups = {
    ex-instance = {
      name_prefix      = "${var.environment.name}-"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      create_attachment = false
    }
  }

  tags = {
    Environment = var.environment.name
    Project     = "ysani-blog"
  }
}

module "blog_ysani_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  name    = "blog_ysani_${var.environment.name}_sg"

  vpc_id = module.blog_ysani_vpc.vpc_id
  
  ingress_rules       = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
