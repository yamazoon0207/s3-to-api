# ECSクラスター
resource "aws_ecs_cluster" "main" {
  name = "json-to-yaml-converter"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# CloudWatch Logsロググループ
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/json-to-yaml-converter"
  retention_in_days = 7
}

# ECSタスク実行ロール
resource "aws_iam_role" "ecs_task_execution" {
  name = "json-to-yaml-converter-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECSタスクロール
resource "aws_iam_role" "ecs_task" {
  name = "json-to-yaml-converter-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# セキュリティグループ
resource "aws_security_group" "ecs_task" {
  name        = "json-to-yaml-converter-task"
  description = "Security group for JSON to YAML converter ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECSタスク定義
resource "aws_ecs_task_definition" "main" {
  family                   = "json-to-yaml-converter"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = var.task_cpu
  memory                  = var.task_memory
  execution_role_arn      = aws_iam_role.ecs_task_execution.arn
  task_role_arn          = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "converter"
      image     = var.container_image
      essential = true

      environment = [
        {
          name  = "S3_BUCKET"
          value = var.s3_bucket_name
        },
        {
          name  = "API_ENDPOINT"
          value = var.api_endpoint
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# EventBridge Scheduler実行ロール
resource "aws_iam_role" "scheduler" {
  name = "json-to-yaml-converter-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["scheduler.amazonaws.com", "events.amazonaws.com"]
        }
      }
    ]
  })
}

# EventBridge SchedulerのECS実行ポリシー
resource "aws_iam_role_policy" "scheduler_ecs" {
  name = "ecs-execution"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task.arn,
          aws_iam_role.ecs_task_execution.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = [aws_cloudwatch_event_rule.s3_event.arn]
      }
    ]
  })
}

# DLQ for EventBridge
resource "aws_sqs_queue" "dlq" {
  name                      = "json-to-yaml-converter-dlq"
  message_retention_seconds = 1209600  # 14日
  kms_master_key_id        = "alias/aws/sqs"

  tags = {
    Name = "json-to-yaml-converter-dlq"
  }
}

# EventBridge Rule for S3 events
resource "aws_cloudwatch_event_rule" "s3_event" {
  name        = "capture-s3-put"
  description = "Capture S3 PUT events"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.s3_bucket_name]
      }
      object = {
        key = [{
          prefix = ""
        }]
      }
    }
  })

  tags = {
    Name = "capture-s3-put"
  }
}

# DLQ Policy for EventBridge
resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn": aws_cloudwatch_event_rule.s3_event.arn
          }
        }
      }
    ]
  })
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "ecs_task" {
  rule      = aws_cloudwatch_event_rule.s3_event.name
  target_id = "RunECSTask"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.scheduler.arn

  dead_letter_config {
    arn = aws_sqs_queue.dlq.arn
  }

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.main.arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"

    network_configuration {
      subnets          = var.subnet_ids
      security_groups  = [aws_security_group.ecs_task.id]
      assign_public_ip = true
    }
  }

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    input_template = <<EOF
{
  "containerOverrides": [
    {
      "name": "converter",
      "environment": [
        {
          "name": "S3_FILE_KEY",
          "value": "<key>"
        }
      ]
    }
  ]
}
EOF
  }
}
