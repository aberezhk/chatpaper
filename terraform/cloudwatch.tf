# CloudWatch log group for index paper lambda function
resource "aws_cloudwatch_log_group" "index_paper_function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.index_papers_lambda.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

# CloudWatch log group for search paper lambda function
resource "aws_cloudwatch_log_group" "search_paper_function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.search_papers_lambda.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}