data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

module "blog_ysani_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.1.0"

  # Autoscaling group
  name = "blog-ysani-asg"

  min_size                  = 1
  max_size                  = 2
  vpc_zone_identifier       = module.blog_ysani_vpc.public_subnets
  security_groups           = [module.blog_ysani_sg.security_group_id]

  #template
  image_id          = data.aws_ami.app_ami.id
  instance_type     = var.instance_type

  traffic_source_attachments = {
    ex-alb = {
      traffic_source_identifier = module.alb.target_groups["ex-instance"].arn
      type       = "elbv2"
    }
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-ysani-alb"
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
      name_prefix      = "blog-"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      create_attachment = false
    }
  }

  tags = {
    Environment = "dev"
    Project     = "Example"
  }
}

module "blog_ysani_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  name    = "blog_ysani_new"

  vpc_id = module.blog_ysani_vpc.vpc_id
  
  ingress_rules       = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
