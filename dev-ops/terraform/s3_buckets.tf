locals {
  website_one_files = fileset("${path.module}/../../apps/web-site-one", "**/*")
  website_two_files = fileset("${path.module}/../../apps/web-site-two", "**/*")
}

# Define your S3 buckets
resource "aws_s3_bucket" "static_website_one" {
  bucket        = "${terraform.workspace}-static-website-bucket-one-yz"
  force_destroy = true
}

resource "aws_s3_bucket" "static_website_two" {
  bucket        = "${terraform.workspace}-static-website-bucket-two-yz"
  force_destroy = true
}

# Configure website settings for both buckets
resource "aws_s3_bucket_website_configuration" "static_website_configuration_one" {
  bucket = aws_s3_bucket.static_website_one.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_website_configuration" "static_website_configuration_two" {
  bucket = aws_s3_bucket.static_website_two.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Set bucket policies for public access
resource "aws_s3_bucket_policy" "bucket_one_public_access_policy" {
  bucket = aws_s3_bucket.static_website_one.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_website_one.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "bucket_two_public_access_policy" {
  bucket = aws_s3_bucket.static_website_two.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_website_two.arn}/*"
      }
    ]
  })
}

# Upload files to bucket one
resource "aws_s3_object" "bucket_one_files" {
  for_each = { for file in local.website_one_files : file => file }
  bucket   = aws_s3_bucket.static_website_one.bucket
  key      = each.value
  source   = "${path.module}/../../apps/web-site-one/${each.value}"
  acl      = "public-read"
}

# Upload files to bucket two
resource "aws_s3_object" "bucket_two_files" {
  for_each = { for file in local.website_two_files : file => file }
  bucket   = aws_s3_bucket.static_website_two.bucket
  key      = each.value
  source   = "${path.module}/../../apps/web-site-two/${each.value}"
  acl      = "public-read"
}
