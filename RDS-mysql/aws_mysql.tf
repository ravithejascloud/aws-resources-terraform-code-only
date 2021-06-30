provider "aws" {
  region     = "us-east-1"
  access_key = 
  secret_key = 
}

resource "aws_vpc" "db-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "DB-VPC"
  }
}

resource "aws_subnet" "db-subnet" {
    vpc_id = aws_vpc.db-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name = "db-subnet-group"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id =aws_vpc.db-vpc.id
    tags = {
        Name ="IGW"
    }
}
resource "aws_route_table" "db_route" {
    vpc_id = aws_vpc.db-vpc.id
    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
    
    tags = {
        Name ="db-ROUTE"
    }
}

resource "aws_route_table_association" "db-rtb-assoc" {
    subnet_id = aws_subnet.db-subnet.id
    route_table_id = aws_route_table.db_route.id
    
}

resource "aws_security_group" "db-sg" {
 vpc_id = aws_vpc.db-vpc.id

 ingress {
     description = "mysql"
     from_port = 3306
     to_port = 3306
     protocol = "tcp"
     cidr_blocks = ["10.0.0.0/16"]
 }
 egress {
     description = "mysql"
     from_port = 0
     to_port = 0
     protocol = "-1"
     cidr_blocks = ["0.0.0.0/0"]
 }

 tags = {
     Name ="db-SG"
 }
}

resource "aws_security_group" "ec2-sg" {
 vpc_id = aws_vpc.db-vpc.id

 ingress {
     description = "ssh"
     from_port = 22
     to_port = 22
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
 }
 ingress {
     description = "mysql"
     from_port = 3306
     to_port = 3306
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
 }
 egress {
     description = "mysql"
     from_port = 0
     to_port = 0
     protocol = "-1"
     cidr_blocks = ["0.0.0.0/0"]
 }

 tags = {
     Name ="ec2-SG"
 }
}

resource "aws_subnet" "ec2-subnet" {
    vpc_id = aws_vpc.db-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
     tags = {
        Name = "ec2-subnet-group"
    }
}


resource "aws_route_table" "ec2-route" {
    vpc_id = aws_vpc.db-vpc.id
    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
    tags = {
        Name ="ec2-ROUTE"
    }
}

resource "aws_route_table_association" "ec2-rtb-assoc" {
    subnet_id = aws_subnet.ec2-subnet.id
    route_table_id = aws_route_table.ec2-route.id
    
}

resource "aws_instance" "mysql-ec2" {
    ami = "ami-0aeeebd8d2ab47354"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.ec2-subnet.id
    security_groups = [aws_security_group.ec2-sg.id]
    key_name = "EC2-KEY-NVIRGINIA"
    associate_public_ip_address = true
    user_data= <<-EOF
               #!/bin/bash
               sudo yum update -y
               sudo rpm -Uvh https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
               sudo yum install mysql-community-server -y
               sudo systemctl enable mysqld 
               sudo systemctl start mysqld
               sudo mysql_secure_installation
               EOF

    tags = {
        Name = "mysql-ec2"
    } 
}

resource "aws_db_subnet_group" "db-subnets" {
  name       = "db-subn-grp"
  subnet_ids = ["${aws_subnet.ec2-subnet.id}","${aws_subnet.db-subnet.id}"]

  tags = {
    Name = "db-subn-grp"
  }
}

resource "aws_db_instance" "mysql-db" {
    engine = "mysql"
    engine_version = "5.7"
    instance_class = "db.t3.micro"
    backup_retention_period  = 7   # in days
    # db_subnet_group_name     = "${var.rds_public_subnet_group}"
    db_subnet_group_name = "${aws_db_subnet_group.db-subnets.name}"
    vpc_security_group_ids   = ["${aws_security_group.db-sg.id}"]
    allocated_storage = 10 # in GB
    multi_az                 = false
    publicly_accessible      = false
    storage_encrypted        = true # you should always do this
    
    name = "ravithejasdb"
    username = "admin"
    password = "ravi0543"
    
    skip_final_snapshot  = true

}

output "db_instance_endpoint" {
    value = "${aws_db_instance.mysql-db.endpoint}"
}

output "ec2-pubip" {
    value = "${aws_instance.mysql-ec2.public_ip}"
}

output "ec2-pvtip" {
    value = "${aws_instance.mysql-ec2.private_ip}"
}