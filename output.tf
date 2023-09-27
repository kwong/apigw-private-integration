output "private_api_url" {
  value = (replace(
    aws_api_gateway_deployment.lambda-api.invoke_url,
    aws_api_gateway_deployment.lambda-api.rest_api_id,
    join("-", [aws_api_gateway_deployment.lambda-api.rest_api_id, aws_vpc_endpoint.apigw_endpoint.id])
  ))
}
