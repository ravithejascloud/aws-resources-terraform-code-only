provider "aws" {
  region = "us-east-1"
}
# get default vpc,subnets,azs from your choice of aws-console region
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
data "aws_availability_zones" "azs" {
    all_availability_zones =true
}
output "subnet_cidr_blocks" {
  value = [for s in data.aws_subnet.subnet : s.cidr_block]
}
output "us-east-1a" {
    value = [ for a in data.aws_subnet.subnet : a.availability_zone]
}
output "pub" {
    value = data.aws_subnet.subnet[0].id
}
output "pvt1" {
    value = data.aws_subnet.subnet[1].id
}
output "pvt2" {
    value = data.aws_subnet.subnet[2].id
}
output "az-no" {

    value =data.aws_availability_zones.azs.names[10]
    
}