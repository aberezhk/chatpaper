# lambda function to index papers based on docker image
# IMPORTANT - before this function can be deployed, index-papers docker image shall be built and pushed to ecr repo
# lambda function is based on container as it allows up to 10 GB and haystack is too big to be deployed as layer otherwise
resource "aws_lambda_function" "index_papers_lambda" {
  function_name = "index-papers-lambda"
  timeout       = 600 # seconds
  image_uri     = "${aws_ecr_repository.ecr_repo.repository_url}:index_papers"
  package_type  = "Image"
  memory_size   = 1024 # MB (otherwise lambda crashes as it runs out of memory)
  reserved_concurrent_executions = 1 # only one lambda can run at a time (cover case when multiple files are uploaded at the same time, we do not want to start this lambda in parallel)

  role = aws_iam_role.lambda_function_role.arn

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.s3_bucket_chat_paper.id, # s3 bucket name where papers are stored and indexed
      API_KEY = var.api_key, # openai api key
      HAYSTACK_TELEMETRY_ENABLED = "False", # disable telemetry (otherwise lambda crashes as haystack tries to write to some folder)
      TRANSFORMERS_CACHE = "/tmp/transformers_cache", # cache for transformers shall be also located in /tmp folder as it is the only writable folder in lambda
      NLTK_DATA = "/tmp", # nltk data shall be located in /tmp folder as it is the only writable folder in lambda (cant make subfolder in /tmp as folder must exist at runtime)
    }
  }
}

# lambda function to search papers based on docker image
# IMPORTANT - before this function can be deployed, search-papers docker image shall be built and pushed to ecr repo
# variables: see description for index_papers_lambda
resource "aws_lambda_function" "search_papers_lambda" {
  function_name = "search-papers-lambda"
  timeout       = 600 # seconds
  image_uri     = "${aws_ecr_repository.ecr_repo.repository_url}:search_papers"
  package_type  = "Image"
  memory_size   = 1024 # MB (otherwise lambda crashes as it runs out of memory)

  role = aws_iam_role.lambda_function_role.arn

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.s3_bucket_chat_paper.id, 
      API_KEY = var.api_key,
      HAYSTACK_TELEMETRY_ENABLED = "False", 
      TRANSFORMERS_CACHE = "/tmp/transformers_cache", 
    }
  }
}

# allow s3 to invoke index papers lambda (lambda is executed when file added to s3 bucket /input folder)
resource "aws_lambda_permission" "index_papers_lambda_allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.index_papers_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_bucket_chat_paper.arn
}

# s3 bucket notification to invoke lambda when new pdf is uploaded to s3 bucket data folder
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.s3_bucket_chat_paper.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.index_papers_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "input/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.index_papers_lambda_allow_bucket]
}
