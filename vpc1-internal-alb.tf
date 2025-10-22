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
  certificate_arn   = "arn:aws:acm:ap-northeast-2:626635430480:certificate/44b7c94c-c21f-4916-aeea-f91f5e18cd25" # SSL 인증서 ARN 필요시

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

############################################################
# Domain-based Routing Configuration (*.country-mouse.net)
############################################################

# API Target Group (api.country-mouse.net)
resource "aws_lb_target_group" "alb_api_tg" {
  name        = "alb-api-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "instance"

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
    Name        = "alb-api-tg"
    Domain      = "api.country-mouse.net"
  }
}

# Web Target Group (web.country-mouse.net)
resource "aws_lb_target_group" "alb_web_tg" {
  name        = "alb-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "instance"

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
    Name        = "alb-web-tg"
    Domain      = "web.country-mouse.net"
  }
}

# App Target Group (app.country-mouse.net) - NLB IP 타겟용
resource "aws_lb_target_group" "alb_app_tg" {
  name        = "alb-app-nlb-tg"  # 이름 변경으로 충돌 방지
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "ip"  # NLB IP를 타겟으로 하기 위해 ip 타입 사용

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"  # Nginx Proxy health check endpoint
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = "dev"
    Name        = "alb-app-nlb-tg"
    Domain      = "app.country-mouse.net"
    Backend     = "Internal-NLB-Nginx-Proxy"
  }
}

# Admin Target Group (admin.country-mouse.net) - NLB IP 타겟용
resource "aws_lb_target_group" "alb_admin_tg" {
  name        = "alb-admin-nlb-tg"  # 이름 변경으로 충돌 방지
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "ip"  # NLB IP를 타겟으로 하기 위해 ip 타입 사용

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"  # Nginx Proxy health check endpoint
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = "dev"
    Name        = "alb-admin-nlb-tg"
    Domain      = "admin.country-mouse.net"
    Backend     = "Internal-NLB-Nginx-Proxy"
  }
}

############################################################
# HTTP Listener Rules - Host-based Routing
############################################################

# api.country-mouse.net → API Target Group
resource "aws_lb_listener_rule" "api_http_rule" {
  listener_arn = aws_lb_listener.alb_internal_http_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_api_tg.arn
  }

  condition {
    host_header {
      values = ["api.country-mouse.net"]
    }
  }

  tags = {
    Name = "api-http-rule"
  }
}

# web.country-mouse.net → Web Target Group
resource "aws_lb_listener_rule" "web_http_rule" {
  listener_arn = aws_lb_listener.alb_internal_http_listener.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_web_tg.arn
  }

  condition {
    host_header {
      values = ["web.country-mouse.net"]
    }
  }

  tags = {
    Name = "web-http-rule"
  }
}

# app.country-mouse.net → App Target Group
resource "aws_lb_listener_rule" "app_http_rule" {
  listener_arn = aws_lb_listener.alb_internal_http_listener.arn
  priority     = 102

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_app_tg.arn
  }

  condition {
    host_header {
      values = ["app.country-mouse.net"]
    }
  }

  tags = {
    Name = "app-http-rule"
  }
}

# admin.country-mouse.net → Admin Target Group
resource "aws_lb_listener_rule" "admin_http_rule" {
  listener_arn = aws_lb_listener.alb_internal_http_listener.arn
  priority     = 103

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_admin_tg.arn
  }

  condition {
    host_header {
      values = ["admin.country-mouse.net"]
    }
  }

  tags = {
    Name = "admin-http-rule"
  }
}

############################################################
# HTTPS Listener Rules - Host-based Routing
############################################################

# api.country-mouse.net → API Target Group (HTTPS)
resource "aws_lb_listener_rule" "api_https_rule" {
  listener_arn = aws_lb_listener.alb_internal_https_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_api_tg.arn
  }

  condition {
    host_header {
      values = ["api.country-mouse.net"]
    }
  }

  tags = {
    Name = "api-https-rule"
  }
}

# web.country-mouse.net → Web Target Group (HTTPS)
resource "aws_lb_listener_rule" "web_https_rule" {
  listener_arn = aws_lb_listener.alb_internal_https_listener.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_web_tg.arn
  }

  condition {
    host_header {
      values = ["web.country-mouse.net"]
    }
  }

  tags = {
    Name = "web-https-rule"
  }
}

# app.country-mouse.net → App Target Group (HTTPS)
resource "aws_lb_listener_rule" "app_https_rule" {
  listener_arn = aws_lb_listener.alb_internal_https_listener.arn
  priority     = 102

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_app_tg.arn
  }

  condition {
    host_header {
      values = ["app.country-mouse.net"]
    }
  }

  tags = {
    Name = "app-https-rule"
  }
}

# admin.country-mouse.net → Admin Target Group (HTTPS)
resource "aws_lb_listener_rule" "admin_https_rule" {
  listener_arn = aws_lb_listener.alb_internal_https_listener.arn
  priority     = 103

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_admin_tg.arn
  }

  condition {
    host_header {
      values = ["admin.country-mouse.net"]
    }
  }

  tags = {
    Name = "admin-https-rule"
  }
}

############################################################
# Target Group Attachments - EC2 인스턴스 연결
############################################################

# API Target Group에 vpc1-ec2 연결
resource "aws_lb_target_group_attachment" "api_attach" {
  target_group_arn = aws_lb_target_group.alb_api_tg.arn
  target_id        = aws_instance.vpc1-ec2.id
  port             = 80
}

# Web Target Group에 vpc1-ec2-2 연결
resource "aws_lb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.alb_web_tg.arn
  target_id        = aws_instance.vpc1-ec2-2.id
  port             = 80
}

# App Target Group에 Internal NLB IP 연결
# 주의: NLB IP는 배포 후 자동으로 할당되므로,
# 초기 배포 시에는 주석 처리하고 NLB 생성 후 IP를 확인하여 수동으로 추가하거나
# data source를 사용하여 동적으로 가져와야 합니다.

# 방법 1: 수동으로 NLB IP 지정 (NLB 생성 후 IP 확인 필요)
# resource "aws_lb_target_group_attachment" "app_nlb_attach_az1" {
#   target_group_arn = aws_lb_target_group.alb_app_tg.arn
#   target_id        = "10.0.1.xxx"  # NLB의 AZ-2a IP (배포 후 확인)
#   port             = 80
#   availability_zone = "ap-northeast-2a"
# }
#
# resource "aws_lb_target_group_attachment" "app_nlb_attach_az2" {
#   target_group_arn = aws_lb_target_group.alb_app_tg.arn
#   target_id        = "10.0.2.xxx"  # NLB의 AZ-2c IP (배포 후 확인)
#   port             = 80
#   availability_zone = "ap-northeast-2c"
# }

# Admin Target Group에 Internal NLB IP 연결
# resource "aws_lb_target_group_attachment" "admin_nlb_attach_az1" {
#   target_group_arn = aws_lb_target_group.alb_admin_tg.arn
#   target_id        = "10.0.1.xxx"  # NLB의 AZ-2a IP (배포 후 확인)
#   port             = 80
#   availability_zone = "ap-northeast-2a"
# }
#
# resource "aws_lb_target_group_attachment" "admin_nlb_attach_az2" {
#   target_group_arn = aws_lb_target_group.alb_admin_tg.arn
#   target_id        = "10.0.2.xxx"  # NLB의 AZ-2c IP (배포 후 확인)
#   port             = 80
#   availability_zone = "ap-northeast-2c"
# }

# 참고: NLB IP 확인 방법
# 1. terraform apply 후 NLB 생성 완료
# 2. AWS CLI로 NLB IP 확인:
#    aws elbv2 describe-load-balancers --names nlb-internal-waf \
#      --query 'LoadBalancers[0].AvailabilityZones[*].[ZoneName,LoadBalancerAddresses[0].IpAddress]' \
#      --output table
# 3. 위 IP들을 target_id에 입력 후 주석 해제
