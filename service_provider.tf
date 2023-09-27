# NLB

# resource "aws_lb" "main" {
#   name               = "service-nlb"
#   internal           = true
#   load_balancer_type = "network"
#   subnets            = module.service-vpc.private_subnets

# }

# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "80"
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.lambda.arn
#   }
# }

# resource "aws_lb_target_group" "lambda" {
#   name        = "lambda-tg"
#   target_type = "lambda"
# }

# resource "aws_lb_target_group_attachment" "lambda" {
#   target_group_arn = aws_lb_target_group.lambda.arn
#   target_id        = aws_lambda_function.api.arn
# }

# resource "aws_lambda_permission" "with_lb" {
#   statement_id  = "AllowExecutionFromlb"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.api.function_name
#   principal     = "elasticloadbalancing.amazonaws.com"
#   source_arn    = aws_lb_target_group.lambda.arn
# }


/*********\
 * Lambda *
\*********/

resource "aws_lambda_function" "api" {
  filename         = "lambda.zip"
  function_name    = "test-function"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = filebase64sha256("lambda.zip")
  runtime          = "python3.9"

  environment {
    # variables = {
    #   PUSHOVER_TOKEN   = var.pushover_token
    #   PUSHOVER_USERKEY = var.pushover_userkey
    # }
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "test-function-lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

# resource "aws_iam_role_policy" "policy_for_lambda" {
#   name = "test-function-lambda-policy"
#   role = aws_iam_role.iam_for_lambda.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#         ]
#         Effect = "Allow"
#       }
#     ]
#   })
# }

resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = "test-function"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda-api.execution_arn}/*/*/*"

  depends_on = [aws_lambda_function.api]
}
