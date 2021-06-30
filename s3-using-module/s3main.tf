# provider "aws" {
#     region = "us-east-1"
#     secret_key = 
#     access_key = 
# }
# create s3 bucket using module
module "s3_bucket_website" {
    source = "C:\\Users\\navee\\Desktop\\aws-demo\\my Terraform lab\\s3"
}
