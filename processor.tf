
#### STATE MANAGEMENT 

terraform {
  backend "s3" {
    bucket = "podcast-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

#### VARIABLES 
variable "region" {
  description = "The AWS region."
}

variable "key_name" {
  description = "The AWS key pair to use for resources."
  default     = "podcast"
}

variable "aws_pem" {
  description = "The path to the .pem file to authenticate over SSH with the cloud host"
}


variable "ami" {
  type        = "map"
  description = "A map of AMIs"
  default     = {}
}

variable "instance_type" {
  description = "The instance type to launch."
  #default     = "t2.micro"
  default = "r4.large"
}

variable "instance_ips" {
  description = "The IPs to use for our instances"
  default     = ["10.0.1.20" ]
#  default     = ["10.0.1.20", "10.0.1.21"]

}

#### BUSINESS LOGIC

data "aws_iam_policy_document" "example" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "example" {
  policy = "${data.aws_iam_policy_document.example.json}"
}

variable "aws_access_key" {
  type = "string" 
  description = "aws secret key"
}

variable "aws_secret_key" {
  type    = "string" 
  description = "aws secret key"
}

provider "aws" {
  #access_key = "${var.aws_access_key}" 
  #secret_key = "${var.aws_secret_key}" 
  region = "us-east-1"
  version = "~> 2.10"
}


## 
module "vpc" {
  source        = "github.com/turnbullpress/tf_vpc.git?ref=v0.0.1"
  name          = "web"
  cidr          = "10.0.0.0/16"
  public_subnet = "10.0.1.0/24"
}

resource "aws_instance" "web" {
  ami                         = "${lookup(var.ami, var.region)}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${module.vpc.public_subnet_id}"
  private_ip                  = "${var.instance_ips[count.index]}"
  #user_data                   = "${file("files/web_bootstrap.sh")}"
  associate_public_ip_address = true

  vpc_security_group_ids = [
    "${aws_security_group.web_host_sg.id}",
  ]

  tags {
    Name = "web-${format("%03d", count.index + 1)}"
  }

  count = "${length(var.instance_ips)}"

  provisioner "file" {
    source      = "files/bootstrap.sh"
    destination = "$HOME/bootstrap.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file(var.aws_pem)}"
    }
  }


  provisioner "file" {
    source      = "tmp/env.sh"
    destination = "$HOME/env.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file(var.aws_pem)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod a+x $HOME/*sh",
      "./bootstrap.sh"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file(var.aws_pem)}"
    }
  }
}

resource "aws_elb" "web" {
  name = "web-elb"
  subnets         = ["${module.vpc.public_subnet_id}"]
  security_groups = ["${aws_security_group.web_inbound_sg.id}"]

 health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/health"
    interval            = 15
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  # The instances are registered automatically
  instances = ["${aws_instance.web.*.id}"]
}

resource "aws_security_group" "web_inbound_sg" {
  name        = "web_inbound"
  description = "Allow HTTP from Anywhere"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_host_sg" {
  name        = "web_host"
  description = "Allow SSH & HTTP to web hosts"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${module.vpc.cidr}"]
  }
 


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#### OUTPUT VARIABLES 
output "elb_address" {
  value = "${aws_elb.web.dns_name}"
}

output "addresses" {
  value = "${aws_instance.web.*.public_ip}"
}

output "public_subnet_id" {
  value = "${module.vpc.public_subnet_id}"
}

