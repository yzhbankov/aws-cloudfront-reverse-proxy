locals {
  reverse_proxy_lambda_path = "${path.module}/../../apps/lambdas/reverse-proxy"
  version_mapping = {
    "v1" = "http://${aws_s3_bucket.static_website_one.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
    "v2" = "http://${aws_s3_bucket.static_website_two.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
  }
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

resource "null_resource" "check_version_mapping_file" {
  provisioner "local-exec" {
    command = "ls -la ${path.module}/version_mapping.json && cat ${path.module}/version_mapping.json"
  }

  depends_on = [local_file.version_mapping_file]
}

# Install Node.js dependencies for Lambda
resource "null_resource" "copy_version_mapping_to_lambda" {
  provisioner "local-exec" {
    command = "cp ${path.module}/version_mapping.json ${local.reverse_proxy_lambda_path}"
  }

  depends_on = [
    local_file.version_mapping_file,
    null_resource.check_version_mapping_file
  ]
}

resource "null_resource" "install_lambda_dependencies" {
  provisioner "local-exec" {
    command = "cd ${local.reverse_proxy_lambda_path} && npm install"
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [null_resource.copy_version_mapping_to_lambda]
}

# Package Lambda function as a zip archive
data "archive_file" "reverse_proxy_lambda" {
  type        = "zip"
  source_dir  = local.reverse_proxy_lambda_path
  output_path = "/tmp/lambda-edge.zip"

  depends_on = [
    null_resource.install_lambda_dependencies,
    null_resource.copy_version_mapping_to_lambda
  ]
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
        Resource = "*"
      }
    ]
  })
}

# Attach the Custom Policy to the Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.reverse_proxy_edge_lambda_role.name
  policy_arn = aws_iam_policy.custom_lambda_policy.arn
}

# Create the Lambda Function
resource "aws_lambda_function" "reverse_proxy_lambda" {
  function_name    = "${terraform.workspace}-lambda-edge-yz"
  role             = aws_iam_role.reverse_proxy_edge_lambda_role.arn
  filename         = data.archive_file.reverse_proxy_lambda.output_path
  handler          = "index.handler"
  source_code_hash = data.archive_file.reverse_proxy_lambda.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30
  publish          = true

  # environment variables not allowed for Lambda Edge

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
}
