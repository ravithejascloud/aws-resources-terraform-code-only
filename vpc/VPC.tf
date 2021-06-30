provider "aws" {
  region     = "us-east-1"
  

resource "aws_vpc" "tfvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tfvpc"
  }
}

resource "aws_subnet" "tfpub" {
  vpc_id     = aws_vpc.tfvpc.id
  cidr_block = "192.168.1.0/24"

  tags = {
    Name = "tfpub"
  }
}

resource "aws_subnet" "tfpvt" {
  vpc_id     = aws_vpc.tfvpc.id
  cidr_block = "192.168.2.0/24"

  tags = {
    Name = "tfpvt"
  }
}

resource "aws_internet_gateway" "tfigw" {
  vpc_id = aws_vpc.tfvpc.id

  tags = {
    Name = "tfigw"
  }
}

resource "aws_eip" "tfeip" {
   vpc      = true
}

resource "aws_nat_gateway" "tfngw" {
  allocation_id = aws_eip.tfeip.id
  subnet_id     = aws_subnet.tfpvt.id
   tags = {
    Name = "tfngw"
  }
}

resource "aws_route_table" "tfrt1" {
  vpc_id = aws_vpc.tfvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tfigw.id
      }
    tags = {
    Name = "tfcustom"
   }
  }

  resource "aws_route_table" "tfrt2" {
  vpc_id = aws_vpc.tfvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tfngw.id
    }
    tags = {
    Name = "tfmainpvt"
    }
  }


  resource "aws_security_group" "tfsg1" {
  name        = "tfsg1"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.tfvpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.tfvpc.cidr_block]
     }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
      }

  tags = {
    Name = "tfsg1"
  }
}


resource "aws_route_table_association" "tfsa1" {
  subnet_id      = aws_subnet.tfpub.id
  route_table_id = aws_route_table.tfrt1.id
}

resource "aws_route_table_association" "tfsa2" {
  subnet_id      = aws_subnet.tfpvt.id
  route_table_id = aws_route_table.tfrt2.id
}
