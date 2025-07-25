provider "aws" {
  region = "ap-south-1"  # Change this to your region
}

# Create SNS topic for alerts
resource "aws_sns_topic" "ec2_alerts" {
  name = "ec2-runtime-alerts"
}

# Subscribe your email to the topic
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.ec2_alerts.arn
  protocol  = "email"
  endpoint  = "mailmemjguru@gmail.com"  # 🔁 CHANGE to your email
}

# Create IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-ec2-alert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach EC2, SNS, and CloudWatch permissions to Lambda role
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-ec2-sns-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.ec2_alerts.arn
      }
    ]
  })
}

# Create ZIP of the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Create the Lambda function
resource "aws_lambda_function" "ec2_checker" {
  function_name = "ec2RuntimeChecker"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.ec2_alerts.arn
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# Create EventBridge rule to run Lambda every 2 minutes
resource "aws_cloudwatch_event_rule" "every_2_min" {
  name                = "ec2CheckerSchedule"
  schedule_expression = "rate(2 minutes)"
}

# Attach the Lambda to the event rule
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.every_2_min.name
  target_id = "ec2RuntimeCheckerTarget"
  arn       = aws_lambda_function.ec2_checker.arn
}

# Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_2_min.arn
}
