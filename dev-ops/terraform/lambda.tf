locals {
  reverse_proxy_lambda_path = "${path.module}/../../apps/lambdas/reverse-proxy"
  lambda_timeout            = 60
}

# Install Node.js dependencies for Lambda
resource "null_resource" "install_lambda_dependencies" {
  provisioner "local-exec" {
    command = "cd ${local.reverse_proxy_lambda_path} && npm install"
  }

  triggers = {
    always_run = timestamp()
  }
}

# Package Lambda function as a zip archive
data "archive_file" "reverse_proxy_lambda" {
  type        = "zip"
  source_dir  = local.reverse_proxy_lambda_path
  output_path = "/tmp/kinesis-lambda.zip"

  depends_on = [null_resource.install_lambda_dependencies]
}

# Define IAM Role for Lambda Function
resource "aws_iam_role" "reverse_proxy_edge_lambda_role" {
  name = "${terraform.workspace}-reverse-proxy-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com",
            "cloudfront.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Create the Lambda Function
resource "aws_lambda_function" "reverse_proxy_lambda" {
  function_name    = "${terraform.workspace}-reverse-proxy-lambda-yz"
  role             = aws_iam_role.reverse_proxy_edge_lambda_role.arn
  filename         = data.archive_file.reverse_proxy_lambda.output_path
  handler          = "index.handler"
  source_code_hash = data.archive_file.reverse_proxy_lambda.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = local.lambda_timeout

  environment {
    variables = {
      WEB_SITE_ONE_URL = "http://${aws_s3_bucket.static_website_one.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
      WEB_SITE_TWO_URL = "http://${aws_s3_bucket.static_website_two.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
}

# Create Custom IAM Policy for Lambda using the specific Lambda version ARN
resource "aws_iam_policy" "custom_lambda_policy" {
  name = "${terraform.workspace}-custom-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ],
        Resource = aws_lambda_function.reverse_proxy_lambda.signing_profile_version_arn
      }
    ]
  })
}

# Attach the Custom Policy to the Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.reverse_proxy_edge_lambda_role.name
  policy_arn = aws_iam_policy.custom_lambda_policy.arn
}
