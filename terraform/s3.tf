# Purpose: Create S3 bucket to store documents and faiss db files
resource "aws_s3_bucket" "s3_bucket_chat_paper" {
  bucket = lower("s3-bucket-chat-paper-${var.account_id}")

  tags = {
    Name        = "Chat paper root bucket"
  }
}

# in s3 bucket following folders will be created
# input/ - to upload pdf files
# processed - to store processed pdf files
# faiss/ - to store faiss db files