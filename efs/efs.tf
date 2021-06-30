provider "aws" {
  region = var.region
}
# get default vpc,subnets from your choice of aws-console region
data "aws_vpc" "default-vpc" {
  default = true
}
data "aws_subnet_ids" "subnet-id" {
  vpc_id = "${data.aws_vpc.default-vpc.id}"
}
data "aws_subnet" "subnet" {                                  
  count = "${length(data.aws_subnet_ids.subnet-id.ids)}"              
  id    = "${tolist(data.aws_subnet_ids.subnet-id.ids)[count.index]}"                       
}    
data "aws_internet_gateway" "default-igw" {
  tags = {
    Name = "Default-igw"
  }
}
data "aws_security_group" "default" {
}
# create EIP for PVT-instances
resource "aws_eip" "pvt-eip1" {
  vpc = true
}
resource "aws_eip" "pvt-eip2" {
  vpc = true
}
# create NGW for PVT-instances
resource "aws_nat_gateway" "efs-natgw1" {
  allocation_id = aws_eip.pvt-eip1.id
  subnet_id     = data.aws_subnet.subnet[1].id
  tags = {
    name = "var.efs-natgw1-name"
  }
}
resource "aws_nat_gateway" "efs-natgw2" {
  allocation_id = aws_eip.pvt-eip2.id
  subnet_id     = data.aws_subnet.subnet[2].id
  tags = {
    name = "var.efs-natgw2-name"
  }
}
# create PUB-INSTANCE
resource "aws_instance" "pub-server" {
  ami             = var.ami
  instance_type   = var.instance_type
  subnet_id       = data.aws_subnet.subnet[0].id
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  key_name        = var.key
  associate_public_ip_address = true
  tags = {
    Name = "PUB-SERVER-1"
  }
}

# create PVT-INSTANCES
resource "aws_instance" "pvt-server" {
  count = 2
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.subnet[count.index+1].id
  security_groups             = [aws_security_group.pvt-sg.id]
  key_name                    = var.key
  tags = {
    Name = "PVT-SERVER-${count.index+1}"
  }
}
# create PUB-SG
resource "aws_security_group" "pub-sg" {
  vpc_id = data.aws_vpc.default-vpc.id
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
    description = "all"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# create PVT-SG
resource "aws_security_group" "pvt-sg" {
  vpc_id = data.aws_vpc.default-vpc.id
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
    description = "all"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# create EFS-SG with 2049 port allowable from PVT-SG 
resource "aws_security_group" "efs-sg" {
  vpc_id = data.aws_vpc.default-vpc.id
  ingress {
    description = "nfs"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.default-vpc.cidr_block}"]
  }
  egress {
    description = "all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_route_table" "igw-route" {
  vpc_id = data.aws_vpc.default-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default-igw.id
  }
  tags = {
    Nmae = "igw-route"
  }
}
resource "aws_route_table" "natgw-route1" {
  vpc_id = data.aws_vpc.default-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.efs-natgw1.id
  }
  tags = {
    Nmae = "natgw-route1"
  }
}
resource "aws_route_table" "natgw-route2" {
  vpc_id = data.aws_vpc.default-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.efs-natgw2.id
  }
  tags = {
    Nmae = "natgw-route2"
  }
}
resource "aws_route_table_association" "igwsub-asso" {
  subnet_id      = data.aws_subnet.subnet[0].id
  route_table_id = aws_route_table.igw-route.id
}
# resource "aws_route_table_association" "natgwsub-asso1" {
#   subnet_id      = data.aws_subnet.subnet[1].id
#   route_table_id = aws_route_table.natgw-route1.id
# }
# resource "aws_route_table_association" "natgwsub-asso2" {
#   subnet_id      = data.aws_subnet.subnet[2].id
#   route_table_id = aws_route_table.natgw-route2.id
# }
# create EFS with lifecycle policy
resource "aws_efs_file_system" "pvt-efs" {
  creation_token = "ravithejas-efs"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
  encrypted = "true"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}
# create mount target, 
# which gives your VMs a way to mount the EFS volume using NFS
resource "aws_efs_mount_target" "efs-mt" {
  count = 2
   file_system_id  = "${aws_efs_file_system.pvt-efs.id}"
   subnet_id = data.aws_subnet.subnet[count.index+1].id
   security_groups = ["${aws_security_group.efs-sg.id}"]
 }