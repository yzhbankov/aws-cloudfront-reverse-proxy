output "aws_region" {
  value = var.AWS_REGION
}

output "website_one_endpoint" {
  value = aws_s3_bucket.static_website_one.website_endpoint
}

output "website_two_endpoint" {
  value = aws_s3_bucket.static_website_two.website_endpoint
}
