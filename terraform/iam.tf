# iam role for lambda  
resource "aws_iam_role" "lambda_function_role" {
  name               = "lambda_function_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : "sts:AssumeRole",
        Effect : "Allow",
        Principal : {
          "Service" : "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# policy to allow writing cloudwatch logs (used by lambda)
resource "aws_iam_policy" "function_logging_policy" {
  name   = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# policy document to allow lambda to access s3
data "aws_iam_policy_document" "lambda_s3_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "s3:*",
    ]
    resources = ["*"]
  }
}

# policy to allow lambda to access s3
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy"
  path        = "/"
  description = "IAM policy to access s3 from lambda"
  policy      = data.aws_iam_policy_document.lambda_s3_policy_document.json
}

# attach cloudwatch policy to lambda role
resource "aws_iam_role_policy_attachment" "index_paper_function_logging_policy_attachment" {
  role = aws_iam_role.lambda_function_role.id
  policy_arn = aws_iam_policy.function_logging_policy.arn
}


# attach s3 policy to lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_function_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}