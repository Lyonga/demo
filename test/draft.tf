DailyServicesUsageLambdaRole: 
    Type: AWS::IAM::Role 
    Properties: 
      RoleName: !Sub "daily-services-usage-lambdarole" 
      Path: / 
      AssumeRolePolicyDocument:               
          Version: '2012-10-17' 
          Statement: 
          - Sid: 'LambdaSSMAssume' 
            Effect: Allow 
            Principal: 
              Service: 
              - lambda.amazonaws.com   
            Action: sts:AssumeRole            
  DailyServicesUsageLambdaRolePolicy: 
    Type: AWS::IAM::Policy 
    DependsOn: [DailyServicesUsageLambdaRole]
    Properties: 
      PolicyName: DailyServicesUsageLambdaRolePolicy 
      PolicyDocument: 
        Statement: 
        - Action: ["logs:DescribeLogStreams", "logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"] 
          Resource: "*"  
          Effect: Allow   
        - Action: ["ce:DescribeCostCategoryDefinition","ce:GetRightsizingRecommendation","ce:GetCostAndUsage", "ce:GetSavingsPlansUtilization","ce:GetAnomalies","ce:GetReservationPurchaseRecommendation","ce:ListCostCategoryDefinitions", "ce:GetCostForecast","ce:GetPreferences","ce:GetReservationUtilization","ce:GetCostCategories","ce:GetSavingsPlansPurchaseRecommendation", "ce:GetDimensionValues","ce:GetSavingsPlansUtilizationDetails","ce:GetAnomalySubscriptions","ce:GetCostAndUsageWithResources", "ce:DescribeReport","ce:GetReservationCoverage","ce:GetSavingsPlansCoverage","ce:GetAnomalyMonitors","ce:DescribeNotificationSubscription", "ce:GetTags","ce:GetUsageForecast","ce:GetCostAndUsage"]
          Resource: "*" 
          Effect: Allow
        - Action: ["ses:*"]
          Resource: "*" 
          Effect: Allow                        
      Roles: [!Ref DailyServicesUsageLambdaRole]




resource "aws_iam_role" "daily_services_usage_lambda_role" {
  name = "daily-services-usage-lambdarole"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "LambdaSSMAssume"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "daily_services_usage_lambda_role_policy" {
  name        = "DailyServicesUsageLambdaRolePolicy"
  description = "IAM Policy for Lambda to access Cost Explorer and other services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:DescribeLogStreams",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ce:DescribeCostCategoryDefinition",
          "ce:GetRightsizingRecommendation",
          "ce:GetCostAndUsage",
          "ce:GetSavingsPlansUtilization",
          "ce:GetAnomalies",
          "ce:GetReservationPurchaseRecommendation",
          "ce:ListCostCategoryDefinitions",
          "ce:GetCostForecast",
          "ce:GetPreferences",
          "ce:GetReservationUtilization",
          "ce:GetCostCategories",
          "ce:GetSavingsPlansPurchaseRecommendation",
          "ce:GetDimensionValues",
          "ce:GetSavingsPlansUtilizationDetails",
          "ce:GetAnomalySubscriptions",
          "ce:GetCostAndUsageWithResources",
          "ce:DescribeReport",
          "ce:GetReservationCoverage",
          "ce:GetSavingsPlansCoverage",
          "ce:GetAnomalyMonitors",
          "ce:DescribeNotificationSubscription",
          "ce:GetTags",
          "ce:GetUsageForecast",
          "ce:GetCostAndUsage"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ses:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  role       = aws_iam_role.daily_services_usage_lambda_role.name
  policy_arn = aws_iam_policy.daily_services_usage_lambda_role_policy.arn
}


resource "aws_cloudwatch_event_rule" "monthly_event_rule" {
  name        = "monthly-event-rule"
  description = "Triggers monthly on the first day at midnight UTC"
  schedule_expression = "cron(0 0 1 * ? *)" # Runs on the 1st day of each month at midnight UTC
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.monthly_event_rule.name
  target_id = "lambda-monthly-trigger"
  arn       = aws_lambda_function.your_lambda_function.arn # Replace with your Lambda function ARN
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.your_lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_event_rule.arn
}

