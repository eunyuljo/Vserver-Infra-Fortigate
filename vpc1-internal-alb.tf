############################################################
# ALB 생성 ( Internal ) 
############################################################
resource "aws_lb" "alb_internal" {
  name               = "alb-internal"
  load_balancer_type = "application"
  subnets            = [tolist(module.vpc1.private_subnets)[0], 
                        tolist(module.vpc1.private_subnets)[1]]

  internal           = true  # 내부용 ALB
  security_groups    = [aws_security_group.alb_internal_sg.id]
  
  tags = {
    Environment = "dev"
    Name        = "alb-internal"
  }
}

# Internal ALB용 보안 그룹
resource "aws_security_group" "alb_internal_sg" {
  name        = "alb-internal-sg"
  description = "Security group for internal ALB"
  vpc_id      = module.vpc1.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.vpc1.vpc_cidr_block]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc1.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-internal-sg"
    Environment = "dev"
  }
}

# HTTP Target Group for Internal ALB
resource "aws_lb_target_group" "alb_internal_http_tg" {
  name        = "alb-internal-http-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "instance"   # EC2 인스턴스 타겟
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  
  tags = {
    Environment = "dev"
    Name        = "alb-internal-http-tg"
  }
}

# HTTPS Target Group for Internal ALB
resource "aws_lb_target_group" "alb_internal_https_tg" {
  name        = "alb-internal-https-tg"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = module.vpc1.vpc_id
  target_type = "instance"   # EC2 인스턴스 타겟
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTPS"
  }
  
  tags = {
    Environment = "dev"
    Name        = "alb-internal-https-tg"
  }
}

# HTTP Listener for Internal ALB
resource "aws_lb_listener" "alb_internal_http_listener" {
  load_balancer_arn = aws_lb.alb_internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_internal_http_tg.arn
  }
}

# HTTPS Listener for Internal ALB (SSL 인증서 필요시 추가)
resource "aws_lb_listener" "alb_internal_https_listener" {
  load_balancer_arn = aws_lb.alb_internal.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:ap-northeast-2:626635430480:certificate/95498647-17d3-4dcb-b69c-aad715823372" # SSL 인증서 ARN 필요시

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_internal_https_tg.arn
  }
}

# Target Group Attachment - EC2 인스턴스를 Target Group에 연결
resource "aws_lb_target_group_attachment" "alb_internal_http_attach" {
  target_group_arn = aws_lb_target_group.alb_internal_http_tg.arn
  target_id        = aws_instance.vpc1-ec2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "alb_internal_https_attach" {
  target_group_arn = aws_lb_target_group.alb_internal_https_tg.arn
  target_id        = aws_instance.vpc1-ec2.id
  port             = 443
}

# 두 번째 EC2를 ALB Target Group에 연결
resource "aws_lb_target_group_attachment" "alb_internal_http_attach_2" {
  target_group_arn = aws_lb_target_group.alb_internal_http_tg.arn
  target_id        = aws_instance.vpc1-ec2-2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "alb_internal_https_attach_2" {
  target_group_arn = aws_lb_target_group.alb_internal_https_tg.arn
  target_id        = aws_instance.vpc1-ec2-2.id
  port             = 443
}