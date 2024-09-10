# Specify the required providers and their versions
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
  }
}

# Specify the provider and region using environment variables
provider "aws" {
  # No need to specify region, access_key, secret_key, or token here if using environment variables
}

# Define a variable for the resource prefix
variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "ignite"
}

# Define a local-exec provisioner to fetch the public IP
resource "null_resource" "fetch_public_ip" {
  provisioner "local-exec" {
    command = "bash ./fetch_public_ip.sh > public_ip.txt"
  }
}

# Read the public IP address from the file
data "local_file" "public_ip" {
  depends_on = [null_resource.fetch_public_ip]
  filename = "${path.module}/public_ip.txt"
}

locals {
  public_ip = trimspace(data.local_file.public_ip.content)
}

# Define a data source to get availability zones for the specified region
data "aws_availability_zones" "available" {}

# Define a VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.resource_prefix}_vpc"
  }
}

# Define a subnet
resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.resource_prefix}_subnet"
  }
}

# Define an internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.resource_prefix}_internet_gateway"
  }
}

# Define a route table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.resource_prefix}_route_table"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

# Define a security group
resource "aws_security_group" "security_group" {
  name        = "${var.resource_prefix}_security_group"
  description = "Allow inbound traffic for MediaWiki"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [format("%s/32", local.public_ip)]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${var.resource_prefix}_key_pair"
  public_key = tls_private_key.private_key.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.private_key.private_key_pem}' > ./${var.resource_prefix}_mediawiki_key_pair.pem"
  }
}

# Define an EC2 instance
resource "aws_instance" "instance" {
  ami           = "ami-0000be0299b63757e"  # Bitnami MediaWiki AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet.id
  key_name      = aws_key_pair.key_pair.key_name

  vpc_security_group_ids = [aws_security_group.security_group.id]

  tags = {
    Name = "${var.resource_prefix}_instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, MediaWiki!" > /home/bitnami/hello.txt
              EOF

  depends_on = [
    aws_security_group.security_group,
    aws_subnet.subnet,
    aws_vpc.vpc,
    aws_key_pair.key_pair
  ]
}

# Allocate an Elastic IP
resource "aws_eip" "eip" {
  instance = aws_instance.instance.id

  tags = {
    Name = "${var.resource_prefix}_eip"
  }

  depends_on = [
    aws_instance.instance
  ]
}

# Output the public IP of the instance
output "instance_public_ip" {
  value = aws_eip.eip.public_ip
}

# Output reminders and login instructions
output "instance_login_instructions" {
  value = <<-EOT
    The login name for your MediaWiki instance is: bitnami
    The private key file has been generated as ${var.resource_prefix}_mediawiki_key_pair.pem.
    Please set the correct permissions for this file using:
    chmod 400 ${var.resource_prefix}_mediawiki_key_pair.pem
    To log in to your instance, use the following command:
    ssh -i ${var.resource_prefix}_mediawiki_key_pair.pem bitnami@${aws_eip.eip.public_ip}.
    The default MediaWiki administrator is 'user'. Use the EC2 instance menu to navigate 
    to the “Monitor & troubleshoot > Get system log” menu item. The password is in the log.
    EOT
}
