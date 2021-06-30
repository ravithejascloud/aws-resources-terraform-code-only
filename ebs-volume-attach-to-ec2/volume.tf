provider "aws" {
  region     = "us-east-1"
  access_key = 
  secret_key = 
}
# NOTE: CREATE ec2 and ebs in same az.
# CREATE an ec2 instance
data "aws_vpc" "default-vpc" {
  default = true
}
data "aws_subnet_ids" "subnet-id" {
  vpc_id = data.aws_vpc.default-vpc.id
}
data "aws_subnet" "subnet" {
  count = length(data.aws_subnet_ids.subnet-id.ids)
  id    = tolist(data.aws_subnet_ids.subnet-id.ids)[count.index]
}
data "aws_security_group" "default" {
  
}
resource "aws_instance" "ec2" {
  ami                         = "ami-02e0bb36c61bb9715"
  instance_type               = "t2.micro"
  availability_zone           = "us-east-1d" # ref. az instaed of subnet_id
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  key_name                    = "EC2-KEY-NVIRGINIA"
  associate_public_ip_address = true
  tags = {
    Name = "ebs-vol-ec2"
  }
}
# create EBS volume
resource "aws_ebs_volume" "ebs" {
  availability_zone = "us-east-1d"
  size              = 50

  tags = {
    Name        = "ec2-volume"
    environment = "test"
  }
}
# attach EBS volume to ec2
resource "aws_volume_attachment" "ebs-ec2" {
  device_name  = "/dev/sdd"
  volume_id    = aws_ebs_volume.ebs.id
  instance_id  = aws_instance.ec2.id
  force_detach = true
}

output "sg" {
  value = data.aws_security_group.default.id
}