region        = "us-east-1"
vpc_name      = "testing"
vpc_cidr      = "192.168.0.0/16"
IGW_name      = "testing-igw"
tfsubnet_name = "tfsubnet-test"
tfsubnet_cidr = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24", "192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]

ami           = "ami-02e0bb36c61bb9715"
instance_type = "t2.micro"
key           = "EC2-KEY-NVIRGINIA"
test-natgw-name = "NATGW"