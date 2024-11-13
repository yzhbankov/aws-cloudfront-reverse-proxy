locals {
  reverse_proxy_lambda_path = "${path.module}/../../apps/lambdas/reverse-proxy"
  version_mapping_file      = "${path.module}/version_mapping.json"
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

resource "null_resource" "copy_version_mapping_to_lambda" {
  provisioner "local-exec" {
    command = "cp ${local.version_mapping_file} ${local.reverse_proxy_lambda_path}/version_mapping.json"
  }

  depends_on = [local_file.version_mapping_file]  # Ensure version mapping file is generated first
}

# Package Lambda function as a zip archive
data "archive_file" "reverse_proxy_lambda" {
  type        = "zip"
  source_dir  = local.reverse_proxy_lambda_path
  output_path = "/tmp/kinesis-lambda.zip"

  depends_on = [
    null_resource.install_lambda_dependencies,
    null_resource.copy_version_mapping_to_lambda  # Ensure the mapping file is copied before packaging
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
  function_name    = "${terraform.workspace}-reverse-proxy-lambda-yz"
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
