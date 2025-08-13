############################################################
# NLB 생성 ( External ) 
############################################################
resource "aws_lb" "nlb_external" {
  name               = "nlb-external"
  load_balancer_type = "network"
  subnets            = [tolist(module.vpc1.public_subnets)[0], 
                        tolist(module.vpc1.public_subnets)[1]]
  internal           = false  # 퍼블릭 NLB이면 false, 내부용이면 true
  security_groups    = [aws_security_group.vpc1_nlb_external_sg.id]
  
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
  
  # 헬스 체크 기본 설정 (필요 시 커스터마이징 가능)
  health_check {
    protocol = "TCP"
    port     = "traffic-port"
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
  target_id        = "10.0.101.101"   # 예: 뒤쪽 EC2의 Private IP
  port             = 80
}


resource "aws_security_group" "vpc1_nlb_external_sg" {
  name        = "nlb-security-external-group"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = module.vpc1.vpc_id # VPC와 연결

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (주의: 실 운영 환경에서는 제한적으로 사용)
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nlb-external-sg"
    Environment = "Test"
  }
}

############################################################
# NLB 생성 ( Internal ) 
############################################################
resource "aws_lb" "nlb_internal" {
  name               = "nlb-internal"
  load_balancer_type = "network"
  subnets            = [tolist(module.vpc1.private_subnets)[0], 
                        tolist(module.vpc1.private_subnets)[1]]

  internal           = true  # 퍼블릭 NLB이면 false, 내부용이면 true
  security_groups    = [aws_security_group.vpc1_nlb_internal_sg.id]
  
  # 태그 예시
  tags = {
    Environment = "dev"
    Name        = "nlb-internal"
  }
}

resource "aws_lb_target_group" "nlb_internal_tg" {
  name        = "nlb-internal-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "instance"   # 인스턴스 모드면 "instance" 사용
  
  # 헬스 체크 기본 설정 (필요 시 커스터마이징 가능)
  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
  
  tags = {
    Environment = "dev"
    Name        = "nlb-intenal-tg"
  }
}

resource "aws_lb_listener" "nlb_internal_listener" {
  load_balancer_arn = aws_lb.nlb_internal.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_internal_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "ec2_internal_attach" {
  target_group_arn = aws_lb_target_group.nlb_internal_tg.arn
  target_id        = aws_instance.vpc1-ec2.id
  port             = 80
}


resource "aws_security_group" "vpc1_nlb_internal_sg" {
  name        = "nlb-security-internal-group"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = module.vpc1.vpc_id # VPC와 연결

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (주의: 실 운영 환경에서는 제한적으로 사용)
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nlb-internal-sg"
    Environment = "Test"
  }
}

