variable "s3_bucket_name" {
  description = "Name of the S3 bucket to monitor"
  type        = string
}

variable "api_endpoint" {
  description = "Endpoint URL for the mock API"
  type        = string
  default     = "https://httpbin.org/put"
}

variable "vpc_id" {
  description = "VPC ID where the task will run"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the task will run"
  type        = list(string)
}

variable "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  type        = string
}

variable "container_image" {
  description = "Container image URI"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = string
  default     = "512"
}
