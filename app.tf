# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_elb" "app-elb" {
  name = "app-dev"

  # The same availability zone as our instances
  availability_zones = ["${split(",", var.availability_zones)}"]
  security_groups = ["${aws_security_group.app-elb-sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/granny/"
    interval            = 30
  }
}

resource "aws_autoscaling_group" "app-asg" {
  availability_zones   = ["${split(",", var.availability_zones)}"]
  name                 = "app-asg"
  max_size             = "${var.asg_max}"
  min_size             = "${var.asg_min}"
  desired_capacity     = "${var.asg_desired}"
  force_delete         = true
  launch_configuration = "${aws_launch_configuration.app-lc.name}"
  load_balancers       = ["${aws_elb.app-elb.name}"]

  tag {
    key                 = "Name"
    value               = "app"
    propagate_at_launch = "true"
  }
}

resource "aws_launch_configuration" "app-lc" {
  name          = "app-launch-configuration"
  image_id      = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  iam_instance_profile = "app"
  associate_public_ip_address = "false"

  # Security group
  security_groups = ["${aws_security_group.app-sg.id}"]
  key_name        = "${var.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "app-elb-sg" {
  name        = "app-elb"
  description = "app tier security group"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app-sg" {
  name        = "app"
  description = "app tier security group"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = ["${aws_security_group.app-elb-sg.id}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
