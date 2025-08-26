############################################################
# NLB 생성 ( External ) 
############################################################
resource "aws_lb" "nlb_external" {
  name               = "nlb-external"
  load_balancer_type = "network"
  subnets            = [tolist(module.vpc1.public_subnets)[0], 
                        tolist(module.vpc1.public_subnets)[1]]
  internal           = false  # 퍼블릭 NLB이면 false, 내부용이면 true
  
  # 태그 예시
  tags = {
    Environment = "dev"
    Name        = "nlb-external"
  }
}

resource "aws_lb_target_group" "nlb_external_tg" {
  name        = "nlb-external-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "ip"   # 인스턴스 모드면 "instance" 사용
  
  # 헬스 체크 기본 설정 - 관리 포트로 변경
  health_check {
    protocol = "TCP"
    port     = "8080"  # 관리 포트로 변경
  }
  
  tags = {
    Environment = "dev"
    Name        = "nlb-extenal-tg"
  }
}

resource "aws_lb_listener" "nlb_external_listener" {
  load_balancer_arn = aws_lb.nlb_external.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_external_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "ip_external_attach" {
  target_group_arn = aws_lb_target_group.nlb_external_tg.arn
  target_id        = "10.0.101.101"   # VIP 전용 Secondary IP
  port             = 80               # 원래대로 복원
}

# HTTPS Target Group for External NLB
resource "aws_lb_target_group" "nlb_external_https_tg" {
  name        = "nlb-external-https-tg"
  port        = 443
  protocol    = "TCP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "ip"

  health_check {
    protocol = "TCP"
    port     = "8080"   # 원래 서비스 포트로 복원
  }

  tags = {
    Environment = "dev"
    Name        = "nlb-external-https-tg"
  }
}

# HTTPS Listener for External NLB
resource "aws_lb_listener" "nlb_external_https_listener" {
  load_balancer_arn = aws_lb.nlb_external.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_external_https_tg.arn
  }
}

# HTTPS Target Group Attachment
resource "aws_lb_target_group_attachment" "ip_external_https_attach" {
  target_group_arn = aws_lb_target_group.nlb_external_https_tg.arn
  target_id        = "10.0.101.101"   # 원래 Secondary IP로 복원
  port             = 443
}



# ############################################################
# # NLB 생성 ( Internal ) 
# ############################################################
# resource "aws_lb" "nlb_internal" {
#   name               = "nlb-internal"
#   load_balancer_type = "network"
#   subnets            = [tolist(module.vpc1.private_subnets)[0], 
#                         tolist(module.vpc1.private_subnets)[1]]

#   internal           = true  # 퍼블릭 NLB이면 false, 내부용이면 true
  
#   # 태그 예시
#   tags = {
#     Environment = "dev"
#     Name        = "nlb-internal"
#   }
# }

# # HTTP Listener는 제거 - HTTPS 전용 구조

# # HTTPS Target Group for Internal NLB (Nginx Backend)
# resource "aws_lb_target_group" "nlb_internal_https_tg" {
#   name        = "nlb-internal-https-tg"
#   port        = 443
#   protocol    = "TCP"
#   vpc_id      = module.vpc1.vpc_id
#   target_type = "instance"   # EC2 인스턴스 타겟
  
#   health_check {
#     protocol            = "TCP"
#     port                = "traffic-port"  
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     timeout             = 5
#     interval            = 30
#   }
  
#   tags = {
#     Environment = "dev"
#     Name        = "nlb-internal-https-tg"
#   }
# }

# # HTTP Target Group for Internal NLB (Nginx Backend)  
# resource "aws_lb_target_group" "nlb_internal_http_tg" {
#   name        = "nlb-internal-http-tg"
#   port        = 80
#   protocol    = "TCP"
#   vpc_id      = module.vpc1.vpc_id
#   target_type = "instance"   # EC2 인스턴스 타겟
  
#   health_check {
#     protocol            = "HTTP"
#     port                = "traffic-port"
#     path                = "/health"
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     timeout             = 5
#     interval            = 30
#   }
  
#   tags = {
#     Environment = "dev"
#     Name        = "nlb-internal-http-tg"
#   }
# }

# # HTTPS Listener for Internal NLB
# resource "aws_lb_listener" "nlb_internal_https_listener" {
#   load_balancer_arn = aws_lb.nlb_internal.arn
#   port              = 443
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.nlb_internal_https_tg.arn
#   }
# }

# # HTTP Listener for Internal NLB
# resource "aws_lb_listener" "nlb_internal_http_listener" {
#   load_balancer_arn = aws_lb.nlb_internal.arn
#   port              = 80
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.nlb_internal_http_tg.arn
#   }
# }


