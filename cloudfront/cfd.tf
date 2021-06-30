provider "aws" {
    region = "us-east-1"
    

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
    key = "index.html"
    source= "C:\\Users\\navee\\Desktop\\aws-demo\\index.html"
}

locals {
  s3_origin_id = "myS3Origin"
}

# we can also easily create s3 static website using module as below:
# where here "source" is the path of the s3_bucket_website creation files
# in your local repo


# cloud front ditribution creation
resource "aws_cloudfront_distribution" "s3_distribution" {
  # origin settings
  origin {
    domain_name = aws_s3_bucket.ravithejas.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  # distribution settings
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  #  To add an alternate domain name (CNAME) to a CloudFront distribution,
  # you must attach a trusted certificate that validates your 
  # authorization to use the domain name

  # aliases = ["ravithejas.xys", "app.ravithejas.xyz"] 
  
  # Cache behavior settings
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
  }
  }
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id    
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
  }
  }
  # restrictions
   restrictions {
    geo_restriction {
      restriction_type = "blacklist" # it will be "none" ,"whiltelist" (means allow) or "blacklist" (means deny)
      locations        = ["US", "CA", "GB", "DE"]
    }
  }
  # viewer certificate 
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


