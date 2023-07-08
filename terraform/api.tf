# The whole configuration was taken from https://mrponath.medium.com/terraform-and-aws-api-gateway-a137ee48a8ac
# with few modifications (marked as changed or added)

# Create API Gateway
# changed name and description
resource "aws_api_gateway_rest_api" "cors_api" {
    name          = "ChatPaperAPI"
    description   = "An API for Chat Paper"
}

# Create API Gateway Resource
# changed path_part
resource "aws_api_gateway_resource" "cors_resource" {
    path_part     = "searchpapers"
    parent_id     = "${aws_api_gateway_rest_api.cors_api.root_resource_id}"
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
}

# Create API Gateway Method for OPTIONS (needed for CORS)
resource "aws_api_gateway_method" "options_method" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
    http_method   = "OPTIONS"
    authorization = "NONE"
}

# Create API Gateway Method Response for OPTIONS
# important are the response_parameters (allowed headers)
resource "aws_api_gateway_method_response" "options_200" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
    http_method   = "${aws_api_gateway_method.options_method.http_method}"
    status_code   = "200"
    response_models = {
        "application/json" = "Empty",
    }
    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = true,
        "method.response.header.Access-Control-Allow-Methods" = true,
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    depends_on = ["aws_api_gateway_method.options_method"]
}

# Create API Gateway Integration for OPTIONS
# added request_templates and passthrough_behavior
resource "aws_api_gateway_integration" "options_integration" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
    http_method   = "${aws_api_gateway_method.options_method.http_method}"
    type          = "MOCK"
    request_templates = {"application/json" = "{\"statusCode\": 200}"}
    passthrough_behavior = "WHEN_NO_MATCH"
    depends_on = ["aws_api_gateway_method.options_method"]
}

# Create API Gateway Integration Response for OPTIONS
# allow orinins is set to allow all origins - it is not secure
# to make it secure you need to set the origin to the domain from which requests are sent
resource "aws_api_gateway_integration_response" "options_integration_response" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
    http_method   = "${aws_api_gateway_method.options_method.http_method}"
    status_code   = "${aws_api_gateway_method_response.options_200.status_code}"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
        "method.response.header.Access-Control-Allow-Origin" = "'*'"
    }
    depends_on = ["aws_api_gateway_method_response.options_200"]
}

# Create API Gateway Method for POST
resource "aws_api_gateway_method" "cors_method" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
    http_method   = "POST"
    authorization = "NONE"
}

# Create API Gateway Method Response for POST
resource "aws_api_gateway_method_response" "cors_method_response_200" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
    http_method   = "${aws_api_gateway_method.cors_method.http_method}"
    status_code   = "200"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    depends_on = ["aws_api_gateway_method.cors_method"]
}

# Create API Gateway Integration for POST
# the proxy integration will forwarad the request to the lambda function search_papers_lambda
# changed uri (region and lambda name)
resource "aws_api_gateway_integration" "integration" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
    http_method   = "${aws_api_gateway_method.cors_method.http_method}"
    integration_http_method = "POST"
    type          = "AWS_PROXY"
    uri           = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.search_papers_lambda.arn}/invocations"
    depends_on    = ["aws_api_gateway_method.cors_method", "aws_lambda_function.search_papers_lambda"]
}

# Deploy api to stage prod
# stage will be created automatically
resource "aws_api_gateway_deployment" "deployment" {
    rest_api_id   = "${aws_api_gateway_rest_api.cors_api.id}"
    stage_name    = "prod"
    depends_on    = ["aws_api_gateway_integration.integration"]
}

# Allow to call lambda from API Gateway
# changed source_arn (region, account id and api id)
resource "aws_lambda_permission" "apigw_lambda" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.search_papers_lambda.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.cors_api.id}/*/*/searchpapers"
}

# Output the url of the api (in cli after running terraform apply)
# added
output "search_papers_url" {
    value = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_resource.cors_resource.path}"
}

