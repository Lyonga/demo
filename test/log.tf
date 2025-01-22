data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/code/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "cost_alert_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.lambda_cost
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  memory_size      = 1024
  timeout          = 300
  environment {
    variables = {
      RECIPIENT   = var.recipient
      SENDER = var.sender
    }
  }
  tags        = var.tags
}
