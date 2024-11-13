locals {
  website_one_files = fileset("${path.module}/../../apps/web-site-one", "**/*")
  website_two_files = fileset("${path.module}/../../apps/web-site-two", "**/*")
  version_mapping = {
    "v1" = "http://${aws_s3_bucket.static_website_one.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
    "v2" = "http://${aws_s3_bucket.static_website_two.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
  }
}

resource "aws_s3_bucket" "static_website_one" {
  bucket        = "${terraform.workspace}-static-website-bucket-one-yz"
  force_destroy = true
}

resource "aws_s3_bucket" "static_website_two" {
  bucket        = "${terraform.workspace}-static-website-bucket-two-yz"
  force_destroy = true
}

# Ensure that version_mapping is updated only after the websites are configured
resource "local_file" "version_mapping_file" {
  filename = "${path.module}/version_mapping.json"
  content  = jsonencode(local.version_mapping)
  depends_on = [
    aws_s3_bucket.static_website_one,
    aws_s3_bucket.static_website_two,
    aws_s3_bucket_website_configuration.static_website_configuration_one,
    aws_s3_bucket_website_configuration.static_website_configuration_two
  ]
}

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

resource "aws_s3_bucket_public_access_block" "static_website_one" {
  bucket                  = aws_s3_bucket.static_website_one.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "static_website_two" {
  bucket                  = aws_s3_bucket.static_website_two.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "bucket_one_files" {
  for_each = { for file in local.website_one_files : file => file }
  bucket   = aws_s3_bucket.static_website_one.bucket
  key      = each.value
  source   = "${path.module}/../../apps/web-site-one/${each.value}"
}

resource "aws_s3_object" "bucket_two_files" {
  for_each = { for file in local.website_two_files : file => file }
  bucket   = aws_s3_bucket.static_website_two.bucket
  key      = each.value
  source   = "${path.module}/../../apps/web-site-two/${each.value}"
}
