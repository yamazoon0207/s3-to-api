# Terraform S3 to API

This Terraform configuration sets up an infrastructure that:
1. Monitors S3 bucket for file uploads
2. Triggers ECS Fargate task when a file is uploaded
3. Processes the file and sends it to an API endpoint

## Files
- \`main.tf\`: Main Terraform configuration
- \`variables.tf\`: Variable definitions
- \`outputs.tf\`: Output definitions
- \`provider.tf\`: AWS provider configuration
- \`ecs_task.py\`: Python script for the ECS task
- \`Dockerfile\`: Container image definition
- \`requirements.txt\`: Python dependencies
- \`terraform.tfvars.example\`: Example variables file

## Usage
1. Copy terraform.tfvars.example to terraform.tfvars
2. Update the variables in terraform.tfvars
3. Run terraform init and terraform apply
