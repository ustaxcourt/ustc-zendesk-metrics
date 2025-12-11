data "aws_region" "current"{}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "rest" {
  name        = "zendesk-metrics-api-gateway"
  description = "Zendesk Metrics"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.common_tags
}

#GET /updateMetricsDatabase
resource "aws_api_gateway_resource" "get_report" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_rest_api.rest.root_resource_id
  path_part   = "get-report"
}

#Methods
resource "aws_api_gateway_method" "get_report_get" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  resource_id   = aws_api_gateway_resource.get_report.id
  http_method   = "GET"
  authorization = "NONE"
}

#lambda integration
resource "aws_api_gateway_integration" "get_report_integration" {
  rest_api_id          = aws_api_gateway_rest_api.rest.id
  resource_id          = aws_api_gateway_resource.get_report.id
  http_method          = aws_api_gateway_method.get_report_get.http_method
  type                 = "AWS_PROXY"
  integration_http_method = "GET"
  uri         = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.lambda_function_arns["getReport"]}/invocations"
}

#Deployment 

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.get_report_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get_report_integration,
  ]
}

#Stage

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  stage_name    = var.stage_name
  tags          = var.common_tags
}

#These should go in api gateway
resource "aws_lambda_permission" "get_report_permission" {
  statement_id  = "AllowAPIGatewayInvokeInit"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arns["getReport"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest.execution_arn}/*/GET/get-report"
}
