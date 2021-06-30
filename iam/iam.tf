provider "aws" {
  region = "us-east-1"
}

# create IAM role which allows S3-read-write for ec2_instance
# the following block allows an entity, permission to assume the role.
resource "aws_iam_role" "service" {
  name               = "service-ec2"
  description        = "creating service for iam-role"
  assume_role_policy = file("iamservice.json")
}
# create IAM policy 
resource "aws_iam_policy" "s3-rw" {
  name        = "access-s3-RW"
  description = "creating policy for iam-role"
  policy      = file("iampolicy.json")
}
# Now attach the policy to service to get IAM-ROLE
resource "aws_iam_policy_attachment" "ec2-s3-RW" {
  name       = "ec2service-s3policy-attachment"
  roles      = ["${aws_iam_role.service.name}"]
  policy_arn = aws_iam_policy.s3-rw.arn
}
