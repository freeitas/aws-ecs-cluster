resource "aws_ssm_parameter" "lb_arn" {
  name  = "/aws/ecs/lb/id"
  value = aws_lb.main.arn
  type  = "String"
}

resource "aws_ssm_parameter" "lb_listener" {
  name  = "/aws/ecs/lb/listerner"
  value = aws_lb_listener.main.arn
  type  = "String"
}