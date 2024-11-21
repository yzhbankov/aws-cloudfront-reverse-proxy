locals {
  reverse_proxy_lambda_path = "${path.module}/../../apps/lambdas/reverse-proxy"
  version_mapping = {
    "v1" = "http://${aws_s3_bucket.static_website_one.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
    "v2" = "http://${aws_s3_bucket.static_website_two.bucket}.s3-website-${var.AWS_REGION}.amazonaws.com"
  }
}

resource "null_resource" "prepare_lambda_environment" {
  provisioner "local-exec" {
    command = <<EOT
    cd ${local.reverse_proxy_lambda_path} &&
    echo '${jsonencode(local.version_mapping)}' > version_mapping.json &&
    npm install
    EOT
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    aws_s3_bucket.static_website_one,
    aws_s3_bucket.static_website_two,
    aws_s3_bucket_website_configuration.static_website_configuration_one,
    aws_s3_bucket_website_configuration.static_website_configuration_two
  ]
}

data "archive_file" "reverse_proxy_lambda" {
  type        = "zip"
  source_dir  = local.reverse_proxy_lambda_path
  output_path = "${path.module}/lambda-edge.zip"

  depends_on = [
    null_resource.prepare_lambda_environment,
  ]
}

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
            "edgelambda.amazonaws.com"
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

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.reverse_proxy_edge_lambda_role.name
  policy_arn = aws_iam_policy.custom_lambda_policy.arn
}

resource "aws_lambda_function" "reverse_proxy_lambda" {
  function_name    = "${terraform.workspace}-proxy-edge-lambda-yz"
  role             = aws_iam_role.reverse_proxy_edge_lambda_role.arn
  filename         = data.archive_file.reverse_proxy_lambda.output_path
  handler          = "index.handler"
  source_code_hash = data.archive_file.reverse_proxy_lambda.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30
  publish          = true

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
}
