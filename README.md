# aws-cloudfront-reverse-proxy
Reverse Proxy Service Based on the AWS CloudFront

## Requirements
- Terraform v1.7.5
- provider registry.terraform.io/hashicorp/aws v5.41.0

## Terraform deployment
### Requirements
- Created AWS account
- Created user with admin rights and downloaded AWS access key for this user `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- The `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` should be stored in the GitHub secrets

### Instructions
- Create any pull request in GutHub
- Comment in pull request `/plan prod`, where `/plan` is the action for terraform and `prod` in workspace
- Check GitHub actions and in case no issues detected proceed with the next step
- Comment in pull request `/apply prod`, where `/apply` is the action for terraform and `prod` in workspace
- Check GitHub action result for errors
- To destroy all created infrastructure comment in pull request `/destroy prod`
