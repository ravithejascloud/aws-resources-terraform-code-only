provider "aws" {
  region     = "us-east-1"
  access_key = 
  secret_key = 
}

# 1.create S3 bucket
resource "aws_s3_bucket" "sgw" {
  bucket = "ravithejas-sgw"
  acl    = "private"
  tags = {
    Name        = "sgway"
    Environment = "test"
  }
}


# 2.create IAM role which allows S3-read-write for ec2_instance
# the following block allows an entity, permission to assume the role.
resource "aws_iam_role" "service" {
  name               = "service-ec2"
  description        = "creating service for iam-role"
  assume_role_policy = file("iamservice.json")
}
# create IAM policy
resource "aws_iam_policy" "s3-rw" {
  name        = "ec2-access-s3-policy"
  description = "creating policy for iam-role"
  policy      = file("iampolicy.json")
}
# Now attach the policy to service to get IAM-ROLE
resource "aws_iam_policy_attachment" "ec2-s3-RW" {
  name       = "ec2service-s3policy-attachment"
  roles      = ["${aws_iam_role.service.name}"]
  policy_arn = aws_iam_policy.s3-rw.arn
}


# first create "host platform" from VMware/MicrosoftHyper/Amzon EC2/Linux KVM etc
# here i choose "Amazon EC2"

# 3.create sgw-ec2 instance 
# getting default vpc,default subnet and default SGs
data "aws_vpc" "default-vpc" {
  default = true
}
data "aws_subnet" "Default" {
  availability_zone = "us-east-1d"
}

# create security group for sgw-ec2 with in default vpc
resource "aws_security_group" "sgw-instance-SG" {

  vpc_id = data.aws_vpc.default-vpc.id

  ingress {
    description = "ssh"
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
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "nfs"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "storage-SG"
    environment = "test"
  }
}
# create sgw-ec2 instance
resource "aws_instance" "sgw-ec2" {
  ami             = "ami-0135b6a290e6d5967"
  instance_type   = "t3.xlarge"
  subnet_id       = data.aws_subnet.Default.id
  security_groups = [aws_security_group.sgw-instance-SG.id]
  key_name        = "EC2-KEY-NVIRGINIA"
  tags = {
    Name        = "SGW-EC2"
    Environment = "test"
  }
}
# create EBS volume
resource "aws_ebs_volume" "sgw-ebs" {
  availability_zone = "us-east-1d"
  size              = 150 # min. is 150gb

  tags = {
    Name        = "sgw"
    environment = "test"
  }
}
# attach EBS volume to sgw-ec2
resource "aws_volume_attachment" "ebs-sgwec2" {
  device_name  = "/dev/xvdp" # for linux kernel virtual-block-device "/dev/xvdp"
  volume_id    = aws_ebs_volume.sgw-ebs.id
  instance_id  = aws_instance.sgw-ec2.id
  force_detach = true
}

# 4.create STORAGE GATEWAY 
resource "aws_storagegateway_gateway" "SGW-S3" {
  gateway_ip_address = aws_instance.sgw-ec2.public_ip
  gateway_name       = "sgw-using-s3"
  gateway_timezone   = "GMT"
  gateway_type       = "FILE_S3"
}
# attach local disk to stoage-gate-way before creating NFS
# a.Before creating the resource "aws_storagegateway_cache", 
# use data to get the disk id.
variable "upload_disk_path" {
  default = "/dev/xvdp"
}

data "aws_storagegateway_local_disk" "upload_disk" {
  disk_path   = var.upload_disk_path
  gateway_arn = aws_storagegateway_gateway.SGW-S3.arn
}

resource "aws_storagegateway_upload_buffer" "stg_upload_buffer" {
  disk_id     = data.aws_storagegateway_local_disk.upload_disk.disk_id
  gateway_arn = aws_storagegateway_gateway.SGW-S3.arn
}
# b.Manages an AWS Storage Gateway cache
resource "aws_storagegateway_cache" "cache" {
  disk_id     = data.aws_storagegateway_local_disk.upload_disk.id
  gateway_arn = aws_storagegateway_gateway.SGW-S3.arn
}

# 5.create NFS file share
resource "aws_storagegateway_nfs_file_share" "NFS" {
  client_list  = [data.aws_vpc.default-vpc.cidr_block]
  gateway_arn  = aws_storagegateway_gateway.SGW-S3.arn
  location_arn = aws_s3_bucket.sgw.arn
  role_arn     = aws_iam_role.service.arn
}