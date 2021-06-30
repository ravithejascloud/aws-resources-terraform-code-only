provider "aws" {
    region = "us-east-1"
    secret_key = 
    access_key = 
}
resource "aws_s3_bucket" "ravithejas" {
    bucket = "ravithejas.xyz"
    acl = "public-read-write"
    policy = file("bucketpolicy.json")
    force_destroy = true
    website {
        index_document="index.html"
          }
}
resource "aws_s3_bucket_object" "website"{
    bucket = aws_s3_bucket.ravithejas.id
    acl = "public-read-write"
    key = "index.html"
    source= "C:\\Users\\navee\\Desktop\\aws-demo\\index.html"
}
