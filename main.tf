data "aws_region" "current" {}

module "consumer-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "consumer-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["ap-southeast-1a", "ap-southeast-1b"]

  enable_nat_gateway = false
  public_subnets     = []
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]

}

module "service-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "service-vpc"
  cidr = "172.16.0.0/16"
  azs  = ["ap-southeast-1a", "ap-southeast-1b"]

  enable_nat_gateway = true
  public_subnets     = ["172.16.3.0/24", "172.16.4.0/24"]
  private_subnets    = ["172.16.1.0/24", "172.16.2.0/24"]

}

# Api gateway


# Create private REST API
resource "aws_api_gateway_rest_api" "lambda-api" {
  name = var.api_gateway_name

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.apigw_endpoint.id]
  }
}

# Configure Proxy resource
resource "aws_api_gateway_resource" "proxy" {
  parent_id   = aws_api_gateway_rest_api.lambda-api.root_resource_id
  path_part   = "{proxy+}"
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
}


resource "aws_api_gateway_method" "proxy" {
  authorization = "NONE"
  http_method   = "ANY"
  resource_id   = aws_api_gateway_resource.proxy.id
  rest_api_id   = aws_api_gateway_rest_api.lambda-api.id
}

resource "aws_api_gateway_integration" "lambda-api" {
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_deployment" "lambda-api" {
  depends_on  = [aws_api_gateway_integration.lambda-api]
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  stage_name  = "prod"
}

resource "aws_api_gateway_rest_api_policy" "policy" {
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource = [
          "execute-api:/*"
        ]
      },
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource = [
          "execute-api:/*"
        ],
        Condition = {
          StringNotEquals = {
            "aws:SourceVpc" = module.service-vpc.vpc_id
          }
        }
      }
    ]
  })
}

resource "aws_vpc_endpoint" "apigw_endpoint" {
  vpc_id              = module.service-vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.service-vpc.private_subnets
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.api-gw-sg.id
  ]
}

resource "aws_vpc_endpoint_policy" "apigw_endpoint_policy" {
  vpc_endpoint_id = aws_vpc_endpoint.apigw_endpoint.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Principal = "*"
        Action = [
          "execute-api:Invoke"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_api_gateway_rest_api.lambda-api.execution_arn}/*"
        ]
      }
    ]
  })
}

# SGs


resource "aws_security_group" "api-gw-sg" {
  name        = "api-gw-sg"
  description = "Allow HTTP/HTTPS"
  vpc_id      = module.service-vpc.vpc_id

  ingress {
    description      = "Allow Inbound HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow Inbound HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}
