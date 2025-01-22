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
