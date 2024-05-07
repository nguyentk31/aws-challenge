provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project = "aws-challenge"
    }
  }
}

provider "aws" {
  alias  = "on_premises"
  region = "us-west-2"
}

### Network
# Transit Gateway
resource "aws_ec2_transit_gateway" "uit" {
  description                     = "Transit gateway connect multi VPC"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  transit_gateway_cidr_blocks     = ["192.168.0.0/24"]

  tags = {
    Name = "transitgw"
  }
}

# VPC1
module "network_vpc1" {
  source = "./modules/network"

  vpc_name               = "vpc1"
  vpc_cidr               = "10.1.0.0/16"
  availability_zones     = ["us-east-1a", "us-east-1b"]
  number_public_subnets  = 2
  number_private_subnets = 2
  nat_gateway            = true
  s3_gateway             = true
  transit_gateway_id     = aws_ec2_transit_gateway.uit.id
  cidr_of_other_vpcs     = ["10.2.0.0/16"]
}

# VPC2
module "network_vpc2" {
  source = "./modules/network"

  vpc_name               = "vpc2"
  vpc_cidr               = "10.2.0.0/16"
  availability_zones     = ["us-east-1c", "us-east-1d"]
  number_public_subnets  = 2
  number_private_subnets = 2
  nat_gateway            = true
  s3_gateway             = true
  transit_gateway_id     = aws_ec2_transit_gateway.uit.id
  cidr_of_other_vpcs     = ["10.1.0.0/16"]
}

### Database
# RDS security group
module "rds_sg" {
  source = "./modules/security_group"

  vpc_id         = module.network_vpc1.vpc_id
  sg_name        = "RDS-SG"
  sg_description = "Security group of RDS instances"
  ingress_rules = [
    {
      description = "Allow MYSQL from Private Subnets"
      port        = 3306
      protocol    = "tcp"
      cidr_blocks = concat(module.network_vpc1.private_subnets_cidr, module.network_vpc2.private_subnets_cidr)
    }
  ]
}

# # DB subnet group
# resource "aws_db_subnet_group" "uit" {
#   name       = "rds-subnet-group"
#   subnet_ids = module.network_vpc1.private_subnets_id
# }

# # RDS instance
# resource "aws_db_instance" "uit" {
#   identifier             = "uit-rds"
#   multi_az               = true
#   instance_class         = "db.t3.micro"
#   allocated_storage      = 20
#   engine                 = "mysql"
#   engine_version         = "8.0.35"
#   username               = "main"
#   password               = "myP4ssword"
#   db_name                = "uit"
#   db_subnet_group_name   = aws_db_subnet_group.uit.name
#   vpc_security_group_ids = [module.rds_sg.id]
#   skip_final_snapshot    = true
# }

### Storage
# EFS security group
module "efs_sg" {
  source = "./modules/security_group"

  vpc_id         = module.network_vpc2.vpc_id
  sg_name        = "EFS-SG"
  sg_description = "Security group of EFS"
  ingress_rules = [
    {
      description = "Allow NFS from Private Subnets"
      port        = 2049
      protocol    = "tcp"
      cidr_blocks = concat(module.network_vpc1.private_subnets_cidr, module.network_vpc2.private_subnets_cidr)
    }
  ]
}

# # EFS
# resource "aws_efs_file_system" "uit" {
#   tags = {
#     Name = "uit-efs"
#   }
# }

# # EFS's Mount Targets
# resource "aws_efs_mount_target" "mount_targets" {
#   count           = length(module.network_vpc2.private_subnets_id)
#   file_system_id  = aws_efs_file_system.uit.id
#   subnet_id       = module.network_vpc2.private_subnets_id[count.index]
#   security_groups = [module.efs_sg.id]
# }

### Compute
# Key pairs
resource "aws_key_pair" "server" {
  key_name   = "server-key"
  public_key = file("./ssh-keys/server.pub")
}

resource "aws_key_pair" "bastion" {
  key_name   = "bastion-key"
  public_key = file("./ssh-keys/bastion.pub")
}

# # Ubuntu AMI
# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["099720109477"] # Canonical
# }

## VPC1
# Bastion host security group
module "bastion_vpc1_sg" {
  source = "./modules/security_group"

  vpc_id         = module.network_vpc1.vpc_id
  sg_name        = "VPC1-BastionHost-SG"
  sg_description = "SG of Bastion host in VPC1"
  ingress_rules = [
    {
      description = "Allow SSH from Internet"
      port        = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# # Bastion host instance
# resource "aws_instance" "bastion_host_vpc1" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = "t3.medium"
#   subnet_id              = module.network_vpc1.public_subnets_id[1]
#   vpc_security_group_ids = [module.bastion_vpc1_sg.id]
#   key_name               = aws_key_pair.bastion.key_name
#   tags = {
#     Name = "VPC1-BastionHost"
#   }
# }

# ALB security group
module "alb_sg" {
  source = "./modules/security_group"

  vpc_id         = module.network_vpc1.vpc_id
  sg_name        = "ALB-SG"
  sg_description = "SG of ALB"
  ingress_rules = [
    {
      description = "Allow HTTP from Internet"
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# # ALB
# resource "aws_lb" "uit" {
#   name               = "VPC1-ALB"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [module.alb_sg.id]
#   subnets            = module.network_vpc1.public_subnets_id
# }

# # ALB's Target Group
# resource "aws_lb_target_group" "uit" {
#   name     = "VPC1-ALB-TargetGroup"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = module.network_vpc1.vpc_id
# }

# # ALB's Listener
# resource "aws_lb_listener" "uit" {
#   load_balancer_arn = aws_lb.uit.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.uit.arn
#   }
# }

# Web Server security group
module "web_server_vpc1_sg" {
  source = "./modules/security_group"

  vpc_id         = module.network_vpc1.vpc_id
  sg_name        = "VPC1-Server-SG"
  sg_description = "SG of Server"
  ingress_rules = [
    {
      description     = "Allow HTTP from ALB"
      port            = 80
      protocol        = "tcp"
      security_groups = [module.alb_sg.id]
    },
    {
      description     = "Allow SSH from Bastion host and Private Subnets"
      port            = 22
      protocol        = "tcp"
      cidr_blocks     = concat(module.network_vpc1.private_subnets_cidr, module.network_vpc2.private_subnets_cidr)
      security_groups = [module.bastion_vpc1_sg.id]
    },
    {
      description     = "Allow All ICMP from Bastion host and Private Subnets"
      port            = -1
      protocol        = "icmp"
      cidr_blocks     = concat(module.network_vpc1.private_subnets_cidr, module.network_vpc2.private_subnets_cidr)
      security_groups = [module.bastion_vpc1_sg.id]
    }
  ]
}

# # Server launch template
# resource "aws_launch_template" "uit" {
#   name_prefix     = "VPC1-ASG-"
#   image_id        = data.aws_ami.ubuntu.id
#   instance_type   = "t3.medium"
#   vpc_security_group_ids = [module.server_vpc1_sg.id]
#   key_name        = aws_key_pair.server.key_name
#   user_data = filebase64("./user-data.sh")
# }

# # ASG
# resource "aws_autoscaling_group" "uit" {
#   name                 = "VPC1-ASG"
#   min_size             = 2
#   max_size             = 3
#   desired_capacity     = 2
#   vpc_zone_identifier  = module.network_vpc1.private_subnets_id

#   launch_template {
#     id      = aws_launch_template.uit.id
#     version = "$Latest"
#   }

#   health_check_type = "ELB"
  
#   tag {
#     key                 = "Name"
#     value               = "VPC1-ASG-Server"
#     propagate_at_launch = true
#   }
# }

# # Attachment ASG - Target group
# resource "aws_autoscaling_attachment" "uit" {
#   autoscaling_group_name = aws_autoscaling_group.uit.id
#   lb_target_group_arn    = aws_lb_target_group.uit.arn
# }

# resource "aws_autoscaling_policy" "scale_down" {
#   name                   = "ASG_scale_down"
#   autoscaling_group_name = aws_autoscaling_group.uit.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = -1
#   cooldown               = 120
# }

# resource "aws_autoscaling_policy" "scale_up" {
#   name                   = "ASG_scale_up"
#   autoscaling_group_name = aws_autoscaling_group.uit.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = 1
#   cooldown               = 120
# }

# resource "aws_cloudwatch_metric_alarm" "scale_down" {
#   alarm_description   = "Monitors CPU utilization"
#   alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
#   alarm_name          = "scale_down"
#   comparison_operator = "LessThanOrEqualToThreshold"
#   namespace           = "AWS/EC2"
#   metric_name         = "CPUUtilization"
#   threshold           = "25"
#   evaluation_periods  = "5"
#   period              = "30"
#   statistic           = "Average"

#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.uit.name
#   }
# }

# resource "aws_cloudwatch_metric_alarm" "scale_up" {
#   alarm_description   = "Monitors CPU utilization"
#   alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
#   alarm_name          = "scale_up"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   namespace           = "AWS/EC2"
#   metric_name         = "CPUUtilization"
#   threshold           = "75"
#   evaluation_periods  = "5"
#   period              = "30"
#   statistic           = "Average"

#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.uit.name
#   }
# }

## VPC2
# Bastion host security group
module "bastion_vpc2_sg" {
  source = "./modules/security_group"

  vpc_id         = module.network_vpc2.vpc_id
  sg_name        = "VPC2-BastionHost-SG"
  sg_description = "SG of Bastion host"
  ingress_rules = [
    {
      description = "Allow SSH from Internet"
      port        = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# # Bastion host instance
# resource "aws_instance" "bastion_host_vpc2" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = "t3.medium"
#   subnet_id              = module.network_vpc2.public_subnets_id[1]
#   vpc_security_group_ids = [module.bastion_vpc2_sg.id]
#   key_name               = aws_key_pair.bastion.key_name
#   tags = {
#     Name = "vpc2-jumpsvr"
#   }
# }

# Server security group
module "server_vpc2_sg" {
  source = "./modules/security_group"

  vpc_id         = module.network_vpc2.vpc_id
  sg_name        = "VPC2-Server-SG"
  sg_description = "Security group of Server"
  ingress_rules = [
    {
      description     = "Allow SSH from Bastion host and Private Subnets"
      port            = 22
      protocol        = "tcp"
      cidr_blocks     = concat(module.network_vpc1.private_subnets_cidr, module.network_vpc2.private_subnets_cidr)
      security_groups = [module.bastion_vpc2_sg.id]
    },
    {
      description     = "Allow All ICMP from Bastion host and Private Subnets"
      port            = -1
      protocol        = "icmp"
      cidr_blocks     = concat(module.network_vpc1.private_subnets_cidr, module.network_vpc2.private_subnets_cidr)
      security_groups = [module.bastion_vpc2_sg.id]
    }
  ]
}

# # Server instance
# resource "aws_instance" "server_vpc2" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = "t3.medium"
#   subnet_id              = module.network_vpc2.private_subnets_id[0]
#   vpc_security_group_ids = [module.server_vpc2_sg.id]
#   key_name               = aws_key_pair.server.key_name
#   tags = {
#     Name = "vpc2-server"
#   }
# }
