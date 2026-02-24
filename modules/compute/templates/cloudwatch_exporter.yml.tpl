region: eu-north-1
metrics:
  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: HTTPCode_Target_4XX_Count
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: HTTPCode_Target_5XX_Count
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: HealthyHostCount
    aws_dimensions: [LoadBalancer, TargetGroup]
    aws_statistics: [Average]