# provider details
provider "aws" {
  region     = "us-east-1"
  
}
# vpc creation
resource "aws_vpc" "asg-vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "ASG-VPC-MAIN"
  }
}

# create internet gateway and attach to vpc
resource "aws_internet_gateway" "asg-igw" {
  vpc_id = aws_vpc.asg-vpc.id
  tags = {
    Name = "ASG-IGW-MAIN"
  }
}

# create route table and attach internet gateway
resource "aws_route_table" "asg-route" {
  vpc_id = aws_vpc.asg-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.asg-igw.id
  }
  tags = {
    name = "asg-route"
  }
}

# create atleast two subnets
resource "aws_subnet" "asg-subnet1" {

  vpc_id            = aws_vpc.asg-vpc.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ASG-SUBNET1"
  }
}

resource "aws_subnet" "asg-subnet2" {

  vpc_id            = aws_vpc.asg-vpc.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "ASG-SUBNET2"
  }
}

# create subnet association to the route-table
resource "aws_route_table_association" "igwsub1-asso" {
  subnet_id      = aws_subnet.asg-subnet1.id
  route_table_id = aws_route_table.asg-route.id
}
resource "aws_route_table_association" "igwsub2-asso" {
  subnet_id      = aws_subnet.asg-subnet2.id
  route_table_id = aws_route_table.asg-route.id
}
# create security group for LB ,LConfig and for ASGs seperately
resource "aws_security_group" "LB-sg" {
  vpc_id = aws_vpc.asg-vpc.id

  ingress {
    description = "HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "LB-SG"
  }
}
# creating ASG security group
resource "aws_security_group" "asg-sg" {
  vpc_id = aws_vpc.asg-vpc.id

  ingress {
    description = "SSH"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ASG-SG"
  }
}

# creating launch configuration security group
resource "aws_security_group" "Lconfig-sg" {
  vpc_id = aws_vpc.asg-vpc.id

  ingress {
    description = "SSH"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "LConfig-SG"
  }
}

# creating ec2-app server security group
resource "aws_security_group" "ec2-sg" {
  vpc_id = aws_vpc.asg-vpc.id

  ingress {
    description = "SSH"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "nfs"
    from_port   = "2049"
    to_port     = "2049"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "EC@-SG"
  }
}

# create ASG-aplication server with user data
resource "aws_instance" "httpd-app-server" {

  ami                         = "ami-0b0af3577fe5e3532"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.asg-subnet1.id
  security_groups             = [aws_security_group.ec2-sg.id]
  key_name                    = "EC2-KEY-NVIRGINIA"
  associate_public_ip_address = true
  user_data                   = <<-EOF

                                #!/bin/bash
                                sudo yum update -y
                                sudo yum install httpd -y
                                sudo service httpd start
                                sudo systemctl enable httpd
                                sudo bash -c 'echo ravi its workinggggg httpd-app-server > /var/www/html/index.html'
                               
                                EOF
  tags = {
    Name = "httpd-app-server"
  }
}

resource "aws_ami_from_instance" "httpd-image" {
  name               = "httpd-ami-image"
  source_instance_id = aws_instance.httpd-app-server.id

  depends_on = [
    aws_instance.httpd-app-server,
  ]
  tags = {
    Name = "httpd-app-server-ami"
  }

}

# create load balancer along with target group using "module"
module "alb" {
  source = "terraform-aws-modules/alb/aws"

  #   creating load balancer
  name = "my-alb"

  load_balancer_type = "application"

  vpc_id          = aws_vpc.asg-vpc.id
  security_groups = [aws_security_group.LB-sg.id]
  subnets         = [aws_subnet.asg-subnet1.id, aws_subnet.asg-subnet2.id]
  #   creating target group
  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      #   targets = [
      #     {
      #       target_id = ""
      #       port = 80
      #     },
      #     {
      #       target_id = ""
      #       port = 8080
      #     }
      #   ]
    }
  ]

  #   https_listeners = [
  #     {
  #       port               = 443
  #       protocol           = "HTTPS"
  #       certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
  #       target_group_index = 0
  #     }
  #   ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "Test"
  }
}


# create ASG along with LaunchConfiguration 
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "httpd-asg-server"

  # Launch configuration
  lc_name = "asg-lc"

  image_id        = aws_ami_from_instance.httpd-image.id
  depends_on = [
    aws_ami_from_instance.httpd-image,
  ]
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.Lconfig-sg.id]
  key_name        = "EC2-KEY-NVIRGINIA"


  # Auto scaling group
  asg_name                  = "httpd-asg"
  vpc_zone_identifier       = [aws_subnet.asg-subnet1.id, aws_subnet.asg-subnet2.id]
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 3
  desired_capacity          = 2
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = "test"
      propagate_at_launch = true
    },
  ]
}