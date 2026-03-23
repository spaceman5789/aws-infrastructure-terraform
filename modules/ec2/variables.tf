variable "project_name" {
    type = string
}

variable "vpc_id" {
    type = string
}

variable "public_subnet_ids" {
    type = list(string)
}

variable "private_app_subnet_ids" {
    type = list(string)
}

variable "alb_sg_id" {
    type = string
}

variable "ec2_sg_id" {
    type = string
}

variable "instance_type" {
    type    = string
    default = "t3.micro"
}

variable "desired_capacity" {
    type    = number
    default = 2
}

variable "min_size" {
    type    = number
    default = 1
}

variable "max_size" {
    type    = number
    default = 3
}




resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}



resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}



resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "main" {
    name_prefix      = "${var.project_name}-lt-"
    image_id         = data.aws_ami.amazon_linux.id
    instance_type    = var.instance_type
    vpc_security_group_ids = [var.ec2_sg_id]

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "${var.project_name}-instance"
        }
    }
}

resource "aws_autoscaling_group" "main" {
    name                = "${var.project_name}-asg"
    desired_capacity    = var.desired_capacity
    min_size            = var.min_size
    max_size            = var.max_size
    vpc_zone_identifier = var.private_app_subnet_ids
    target_group_arns   = [aws_lb_target_group.main.arn]

    launch_template {
        id      = aws_launch_template.main.id
        version = "$Latest"
    }
}
