# container registry to store index paper and serach paper containers
# ecr repo shall be created before lambda functions (can be also done manually in the aws console)
# the next step is to build docker images and push them to ecr repo
# and only then lambda functions that use these images can be created
resource "aws_ecr_repository" "ecr_repo" {
 name                 = var.ecr
 image_tag_mutability = "MUTABLE"

 image_scanning_configuration {
   scan_on_push = true
 }
}