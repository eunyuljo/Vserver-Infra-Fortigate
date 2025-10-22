############################################################
# Internal NLB for WAF (Network Load Balancer)
# 용도: Internal ALB Target Groups → Internal NLB → WAF Instances → Backend EC2
############################################################

# Single Internal NLB for all domains
resource "aws_lb" "nlb_internal_waf" {
  name               = "nlb-internal-waf"
  load_balancer_type = "network"
  internal           = true  # Internal NLB
  subnets            = [tolist(module.vpc1.private_subnets)[0],
                        tolist(module.vpc1.private_subnets)[1]]

  enable_cross_zone_load_balancing = false

  tags = {
    Environment = "dev"
    Name        = "nlb-internal-waf"
    Purpose     = "WAF load balancing for all domains"
  }
}

############################################################
# Target Group for Internal NLB → WAF Instances
############################################################

# WAF Target Group (Port 80) - 모든 도메인 공유
resource "aws_lb_target_group" "nlb_waf_tg" {
  name        = "nlb-waf-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.vpc1.vpc_id
  target_type = "instance"  # WAF EC2 인스턴스를 타겟으로

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "TCP"
    port                = 80
  }

  tags = {
    Environment = "dev"
    Name        = "nlb-waf-tg"
  }
}

############################################################
# NLB Listener (Port 80)
############################################################

# NLB Listener for HTTP traffic
resource "aws_lb_listener" "nlb_waf_listener" {
  load_balancer_arn = aws_lb.nlb_internal_waf.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_waf_tg.arn
  }
}

############################################################
# Nginx Proxy Instances (WAF 대신 프록시로 사용)
############################################################

# Nginx Proxy Instance #1 (AZ-2a)
resource "aws_instance" "proxy_instance_1" {
  ami           = "ami-024ea438ab0376a47"  # Ubuntu 24.04
  instance_type = "t3.micro"
  subnet_id     = tolist(module.vpc1.private_subnets)[2]  # Private subnet AZ-2a
  vpc_security_group_ids = [aws_security_group.waf_sg.id]
  key_name      = "eyjo-fnf-test-key"

  source_dest_check = false  # Proxy 역할이므로 필수
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              apt-get update -y

              # Install nginx
              apt-get install -y nginx

              # Create nginx proxy configuration
              cat > /etc/nginx/sites-available/proxy <<'NGINXCONF'
              server {
                  listen 80 default_server;
                  server_name _;

                  # Access logs
                  access_log /var/log/nginx/proxy_access.log;
                  error_log /var/log/nginx/proxy_error.log;

                  location / {
                      # Proxy to backend EC2 instances
                      # 실제 백엔드 IP는 나중에 설정 필요
                      proxy_pass http://10.0.1.100;  # vpc1-ec2 private IP

                      # Preserve Host header
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;

                      # Proxy timeouts
                      proxy_connect_timeout 60s;
                      proxy_send_timeout 60s;
                      proxy_read_timeout 60s;
                  }

                  # Health check endpoint
                  location /health {
                      access_log off;
                      return 200 "OK\n";
                      add_header Content-Type text/plain;
                  }
              }
              NGINXCONF

              # Enable the site
              ln -sf /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/default

              # Test and reload nginx
              nginx -t
              systemctl restart nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "proxy-instance-1"
    Environment = "dev"
    AZ = "ap-northeast-2a"
    Role = "nginx-proxy"
  }
}

# Nginx Proxy Instance #2 (AZ-2c) - 고가용성 구성
resource "aws_instance" "proxy_instance_2" {
  ami           = "ami-024ea438ab0376a47"  # Ubuntu 24.04
  instance_type = "t3.micro"
  subnet_id     = tolist(module.vpc1.private_subnets)[3]  # Private subnet AZ-2c
  vpc_security_group_ids = [aws_security_group.waf_sg.id]
  key_name      = "eyjo-fnf-test-key"

  source_dest_check = false
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              apt-get update -y

              # Install nginx
              apt-get install -y nginx

              # Create nginx proxy configuration
              cat > /etc/nginx/sites-available/proxy <<'NGINXCONF'
              server {
                  listen 80 default_server;
                  server_name _;

                  # Access logs
                  access_log /var/log/nginx/proxy_access.log;
                  error_log /var/log/nginx/proxy_error.log;

                  location / {
                      # Proxy to backend EC2 instances
                      proxy_pass http://10.0.2.100;  # vpc1-ec2-2 private IP

                      # Preserve Host header
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;

                      # Proxy timeouts
                      proxy_connect_timeout 60s;
                      proxy_send_timeout 60s;
                      proxy_read_timeout 60s;
                  }

                  # Health check endpoint
                  location /health {
                      access_log off;
                      return 200 "OK\n";
                      add_header Content-Type text/plain;
                  }
              }
              NGINXCONF

              # Enable the site
              ln -sf /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/default

              # Test and reload nginx
              nginx -t
              systemctl restart nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "proxy-instance-2"
    Environment = "dev"
    AZ = "ap-northeast-2c"
    Role = "nginx-proxy"
  }
}

############################################################
# WAF Security Group
############################################################

resource "aws_security_group" "waf_sg" {
  name        = "waf-security-group"
  description = "Security group for WAF instances"
  vpc_id      = module.vpc1.vpc_id

  # HTTP from Internal ALB subnets
  ingress {
    description = "Allow HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.vpc1.vpc_cidr_block]
  }

  # HTTPS from Internal ALB subnets
  ingress {
    description = "Allow HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc1.vpc_cidr_block]
  }

  # SSH for management
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Private IP 대역만 허용
  }

  # ICMP for health checks
  ingress {
    description = "Allow ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [module.vpc1.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "waf-sg"
    Environment = "dev"
  }
}

############################################################
# Target Group Attachments - Nginx Proxy Instances to NLB Target Group
############################################################

# Proxy Instance #1 Attachment
resource "aws_lb_target_group_attachment" "proxy_attach_1" {
  target_group_arn = aws_lb_target_group.nlb_waf_tg.arn
  target_id        = aws_instance.proxy_instance_1.id
  port             = 80
}

# Proxy Instance #2 Attachment
resource "aws_lb_target_group_attachment" "proxy_attach_2" {
  target_group_arn = aws_lb_target_group.nlb_waf_tg.arn
  target_id        = aws_instance.proxy_instance_2.id
  port             = 80
}

############################################################
# Outputs
############################################################

output "nlb_waf_dns" {
  description = "DNS name of Internal NLB for WAF"
  value       = aws_lb.nlb_internal_waf.dns_name
}

output "nlb_waf_arn" {
  description = "ARN of Internal NLB for WAF"
  value       = aws_lb.nlb_internal_waf.arn
}

output "nlb_waf_tg_arn" {
  description = "ARN of WAF Target Group"
  value       = aws_lb_target_group.nlb_waf_tg.arn
}
