ifneq (, $(wildcard ./.env))
	include .env
	export
endif

terraform_apply:
	cd terraform && terraform apply
terraform_destroy:
	cd terraform && terraform destroy
terraform_output:
	cd terraform && terraform output

deploy_index_papers:
	cd aws_lambda_functions/index_papers && docker build -t python-lambda-function-index-papers .
	docker tag python-lambda-function-index-papers:latest ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/chat-paper-ecr-repo:index_papers
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/chat-paper-ecr-repo:index_papers

deloy_search_papers:
	cd aws_lambda_functions/searchpapers && docker build -t python-lambda-function-search-papers .
	docker tag python-lambda-function-search-papers:latest ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/chat-paper-ecr-repo:search_papers
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/chat-paper-ecr-repo:search_papers
