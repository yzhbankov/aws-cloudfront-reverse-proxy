locals {
  website_one_files = fileset("${path.module}/../../apps/web-site-one", "**/*")
  website_two_files = fileset("${path.module}/../../apps/web-site-two", "**/*")
}

resource "aws_s3_bucket" "static_website_one" {
  bucket        = "${terraform.workspace}-static-website-bucket-one-yz"
  force_destroy = true
}

resource "aws_s3_bucket" "static_website_two" {
  bucket        = "${terraform.workspace}-static-website-bucket-two-yz"
  force_destroy = true
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

  depends_on = [aws_s3_bucket_public_access_block.static_website_one]
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

  depends_on = [aws_s3_bucket_public_access_block.static_website_two]
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

  # Set content_type based on file extension
  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml"
  }, regex("[^.]+$", each.value), "application/octet-stream")
}

resource "aws_s3_object" "bucket_two_files" {
  for_each = { for file in local.website_two_files : file => file }
  bucket   = aws_s3_bucket.static_website_two.bucket
  key      = each.value
  source   = "${path.module}/../../apps/web-site-two/${each.value}"

  # Set content_type based on file extension
  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml"
  }, regex("[^.]+$", each.value), "application/octet-stream")
}
