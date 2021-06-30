provider "aws" {
    region = "us-east-1"
    secret_key = 
    access_key = 
}
# creating hosted zone 
resource "aws_route53_zone" "ravithejas" {
    name = "ravithejas.xyz"
}
#  create record using simple routing
resource "aws_route53_record" "app"{
    zone_id = aws_route53_zone.ravithejas.zone_id
    name = "app" #naming with hosted zone or not it will apply "app.ravithejas.xyz"
    type = "NS"
    ttl ="30" # in seconds
    records = [aws_route53_zone.ravithejas.name]
}
# create record using weighted routing policy
# (same as for all other routings except simple routing)
resource "aws_route53_record" "shop"{
    zone_id = aws_route53_zone.ravithejas.zone_id
    name = "shop.ravithejas.xyz"
    type = "CNAME"  # NS NOT SUPPORTED IN WEIGHTED ROUTING
    ttl ="30" # in seconds
    weighted_routing_policy {
            weight = 90
            }
      set_identifier = "shop"
      records = [aws_route53_zone.ravithejas.name]
}
# create alias record (alias is LB)
# here i do not have LB thats why im creating one
# in real time need to provide "on premises running LB" dns & zone details.
resource "aws_elb" "test-LB" {

    name = "route53-record-purpose"
    availability_zones = ["us-east-1d"]

    listener {
            lb_protocol = "http"
            lb_port = "80"
            instance_protocol = "http"
            instance_port = "80"
             }
}  

resource "aws_route53_record" "LB" {
    zone_id = aws_route53_zone.ravithejas.zone_id
    name = "elb"
    type = "A"

    alias {
        name = aws_elb.test-LB.dns_name
        zone_id = aws_elb.test-LB.zone_id
        evaluate_target_health = true

    }
}

# Enabling the allow_overwrite argument will allow 
# managing NS and SOA records (for the zone are automatically created)
resource "aws_route53_record" "ravithejas" {
  allow_overwrite = true
  name            = "ravithejas.xyz"
  ttl             = 172800
  type            = "NS"
  zone_id         = aws_route53_zone.ravithejas.zone_id

  records = [
# here you can manage 'value/route' you want
# generally we have 04 routes in automatic generated NS record
    aws_route53_zone.ravithejas.name_servers[0], 
    aws_route53_zone.ravithejas.name_servers[1],
    aws_route53_zone.ravithejas.name_servers[2],
    aws_route53_zone.ravithejas.name_servers[3],
  ]
  
}

# create cloudfront distributin alias record
# here already i've created cloudfront distribution resource
# just i'm mentioning that cfd credentials

data "aws_cloudfront_distribution" "test" {
  id = "E31PM0QC2PD2ET" # mention your cloud front ID
}
resource "aws_route53_record" "cloudfront" {
    zone_id = aws_route53_zone.ravithejas.zone_id
    name = "cfd"
    type = "A"

    alias {
        name = data.aws_cloudfront_distribution.test.domain_name
        zone_id = data.aws_cloudfront_distribution.test.hosted_zone_id
        evaluate_target_health = true

    }
}

output "cfd-hosted-zone"{
    value = data.aws_cloudfront_distribution.test.hosted_zone_id
}
