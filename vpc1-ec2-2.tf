resource "aws_instance" "vpc1-ec2-2" {
  ami           = "ami-049788618f07e189d" # 마켓플레이스 AMI ID
  instance_type = "t3.micro"

  tags = {
    Name = "vpc1-private-ec2-2"
  }

  # 필수 사항으로 NAT 처리를 위해 ENI 의 소스/대상 IP를 확인하면 안된다. 
  source_dest_check = false

  # 선택적으로 추가 가능
  key_name = "eyjo-fnf-test-key" # SSH 접속을 위한 키 페어
  subnet_id = module.vpc1.private_subnets[1]  # 다른 AZ의 private subnet 사용
  vpc_security_group_ids = [aws_security_group.vpc1_ec2_sg_2.id] # 새로운 보안 그룹
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  # EC2 시작 시 Apache 설치 및 실행
}

# 두 번째 EC2용 보안그룹 
resource "aws_security_group" "vpc1_ec2_sg_2" {
  name        = "ec2-security-group-2"
  description = "Allow SSH and HTTP traffic for second EC2"
  vpc_id      = module.vpc1.vpc_id # VPC와 연결

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (주의: 실 운영 환경에서는 제한적으로 사용)
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (주의: 실 운영 환경에서는 제한적으로 사용)
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (주의: 실 운영 환경에서는 제한적으로 사용)
  }

# ICMP(Ping) 허용
  ingress {
    description = "Allow ICMP (Ping)"
    from_port   = -1   # ICMP의 모든 타입 허용
    to_port     = -1   # ICMP의 모든 코드 허용
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (운영 환경에서는 제한 필요)
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg-2"
    Environment = "Test"
  }
}