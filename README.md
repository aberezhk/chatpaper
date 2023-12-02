
# Chat paper - document question answering tool with serverless Haystack/ChatGPT deployment in AWS (Lambda Container)

This project is a question answering tool that allows to ask questions about uploaded to S3 bucket papers (or any other pdf files).

**[Haystack](https://haystack.deepset.ai/)** was used to develop two core components.

 - *Index papers component* - enables indexing papers by reading new PDF files from an S3 folder, processing them, and uploading them to a FAISS DB (DB file is also stored in S3).  
 -  *Search papers component* allows to ask questions about papers. This function accepts HTTP POST request with question, picks 5 most relevant documents from FAISS DB, submits a prompt to OpenAI API and finally returns a summarized generated answer with references to the identified documents.


To deploy the project, a **serverless infrastructure is set up on AWS with Terraform**.
Each component is deployed as a separate AWS Lambda Container. Other AWS services used are - API Gateway (for API request handling), S3 (for file storage), ECR (Elastic Container Registry for container management), and CloudWatch (for monitoring and logging).

Additionally, a basic user interface is provided through an HTML/JS file.

This project does not involve training any models from scratch. **Pre-trained models from OpenAI** are used, with an API_KEY enabling access to the necessary resources.

## Project Structure
The code is organized in three folders.

**aws_lambda_function** folder contains all the code needed to build index paper and search paper components: Dockerfile, *_papers.py, requirements.txt

**terraform** folder has terraform files to build infrastructure. Ex.: lambda, api gateway, ecr, cloudwatch, etc.

 **web** folder has a simple html file with a form to send requests to search paper function.

  **files in the root:**
 - *chat_paper_poc.ipynd* - notebook used in collab for prototyping  
 - *Makefile* - commands to automate docker and terraform deployment (requires an *.env* file in root folder with AWS_ACCOUNT_ID parameter)

## How to deploy the project


#### Tools needed

 - AWS account and installed AWS CLI 
 - Terraform CLI (authenticated with AWS CLI)
 - Docker
 - OpenAI account with enabled payments and API token
 - Make (optional)

#### Step 1 - create ECR repo

Create AWS ECR repo (to store containers with index paper and search paper components). This can be done either manually in AWS console: https://aws.amazon.com/ecr/ or with terraform (see *terraform/ecr.tf*). It is important to create ecr repo in the correct region. For example this project is hosted in **eu-central-1** (see *terraform/variables.tf*)

> After this step an ECR repo chat-paper-ecr-repo shall be present in AWS.

#### Step 2 - Build Containers

Build and deploy containers to ECR. In the Makefile there are 2 scripts to help with it - *deploy_index_papers* and *deploy_search_papers*. These commands can be also executed manually from cli. Most likely you will be requested to authenticate to ECR. I use folowing command `aws ecr get-login --region eu-central-1`. As an output it gives something like code below. I copy paste it in cli and execute it.

    docker login -u AWS -p eyJwYXlsb2FkIjoiMjBnY3lrYmJLcXN...joiREFUQV9LRVkiLCJleHBpcmF0aW9uIjoxNjg4Nzg3MzkyfQ== -e none https://1234567890.dkr.ecr.eu-central-1.amazonaws.com

> After these steps there must be 2 containers available in ECR repository. One with tag index_papers and another search_papers.

#### Step 3 - Deploy Infrastructure

Use **terraform** to create the rest of the infrastructure. Either use *Makefile* or simply run `terraform apply` from */terraform folder*. Since in the *variables.tf* file there are 2 variables that do not have default value, you will be prompted to enter them (**account_id** - aws account id and **api_key** - OpenAI API key) manually.  Alternatively one can add these default values to variables.tf. 

Note **search_papers_url** from the terraform output, it will be needed in step 4.

> After this step the whole infrastructure shall be up and running

  
#### Step 4 - Query papers

To send a question to the papers a POST request shall be made to **search_papers_url** (from step 3). Request must have following body structure: {"question": "what is ....?" }.

To use the UI html to send requests replace **search_papers_url** with actual value in `var url = "search_papers_url";`

The answer shall arrive within 2-10 seconds (or little bit more in case of Lambda cold start)
  

## Lessons Learned
 
While developing this project following challenges were faced

 - It is not possible to use simple lambda, because haystack is too big to be deployed as a layer
 -  When configuring lambda it was important to: (1) set lambda size to 1024MB - otherwise out of memory; (2) set lambda env variables so that everything is written to /tmp folder (3) add extra slash in the FAISS path (sqlite////temp...) 
 - It is not possible to use some libraries due to lambda limitations - haystack pdf converter with semlock issue

#### Some usefull materials that helped me build this project

https://medium.com/akava/deploying-containerized-aws-lambda-functions-with-terraform-7147b9815599
https://awstip.com/deploy-lambda-function-python-from-a-container-aws-ecr-using-terraform-3b79d2291464
https://dev.to/aws-builders/provision-aws-elastic-container-registry-repository-using-terraform-373g
https://mrponath.medium.com/terraform-and-aws-api-gateway-a137ee48a8ac
https://haystack.deepset.ai/tutorials
