# 1. Create the IAM Role
resource "aws_iam_role" "monitoring_role" {
  name = "monitoring-discovery-role"

  # This policy allows EC2 service to "assume" (use) this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "monitoring_policy" {
  name        = "PrometheusEC2Discovery"
  # JSON policy that allows ec2:DescribeInstances...
}


# 2. Attach your policy to this role
resource "aws_iam_role_policy_attachment" "monitoring_attach" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

# 3. Create the Instance Profile (the bridge to EC2)
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "monitoring-instance-profile"
  role = aws_iam_role.monitoring_role.name
}