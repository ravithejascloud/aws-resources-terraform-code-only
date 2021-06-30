provider "aws" {
  region = var.region
}

resource "aws_vpc" "tfvpc" {
  cidr_block           = var.vpc_cidr 
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vpc_name}"
  }
}

data "aws_availability_zones" "azs" {}

resource "aws_subnet" "tfsubnet" {
  count             = length(data.aws_availability_zones.azs.names)
  vpc_id            = aws_vpc.tfvpc.id
  cidr_block        = element(var.tfsubnet_cidr, count.index)
  availability_zone = element(data.aws_availability_zones.azs.names, count.index)

  tags = {
    Name = "${var.tfsubnet_name}-${count.index + 1}"
  }
}



resource "aws_internet_gateway" "tfigw" {
  vpc_id = aws_vpc.tfvpc.id

  tags = {
    Name = "${var.IGW_name}"
  }
}

resource "aws_eip" "test-eip" {
  vpc = true
}

resource "aws_nat_gateway" "test-natgw" {
  allocation_id = aws_eip.test-eip.id
  subnet_id     = aws_subnet.tfsubnet[0].id
  
  tags = {
    name = "var.test-natgw-name"
  }

}

resource "aws_instance" "pub-server" {
  count = 2
  ami             = var.ami
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.tfsubnet[0].id
  security_groups = [aws_security_group.pub-sg.id]
  key_name        = var.key
  associate_public_ip_address = true


  tags = {
    Name = "PUB-SERVER-${count.index+1}"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install httpd -y
              sudo service httpd start
              sudo systemctl enable httpd
              sudo bash -c 'echo ravi its workinggggg server1 > /var/www/html/index.html'
              EOF
}

resource "aws_instance" "pvt-server" {
  count = 2
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.tfsubnet[1].id
  security_groups             = [aws_security_group.pvt-sg.id]
  key_name                    = var.key
  user_data                   = <<-EOF
                                #!/bin/bash
                                sudo yum update -y
                                sudo yum install httpd -y
                                sudo service httpd start
                                sudo systemctl enable httpd
                                sudo bash -c 'echo ravi its workinggggg server2 > /var/www/html/index.html'
                                EOF

  tags = {
    Name = "PVT-SERVER-${count.index+1}"
  }
}

resource "aws_security_group" "pub-sg" {

  vpc_id = aws_vpc.tfvpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "icmp"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "pvt-sg" {

  vpc_id = aws_vpc.tfvpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "icmp"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route_table" "igw-route" {
  vpc_id = aws_vpc.tfvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tfigw.id
  }
  tags = {
    Nmae = "igw-route"
  }
}

resource "aws_route_table" "natgw-route" {
  vpc_id = aws_vpc.tfvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.test-natgw.id
  }
  tags = {
    Nmae = "natgw-route"
  }
}

resource "aws_route_table_association" "igwsub-asso" {
  subnet_id      = aws_subnet.tfsubnet[0].id
  route_table_id = aws_route_table.igw-route.id
}

resource "aws_route_table_association" "natgwsub-asso" {
  subnet_id      = aws_subnet.tfsubnet[1].id
  route_table_id = aws_route_table.natgw-route.id
}