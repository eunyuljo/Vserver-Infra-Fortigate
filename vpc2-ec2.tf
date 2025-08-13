# resource "aws_instance" "vpc2-ec2" {
#   #ami           = "ami-049788618f07e189d" # AL2023
#   ami           = "ami-024ea438ab0376a47"  # ubuntu 24.04
#   instance_type = "t3.micro"

#   tags = {
#     Name = "vpc2-private-ec2"
#   }

#   # 필수 ENI 의 소스/대상 IP를 확인하면 안된다. 
#   source_dest_check = false

#   # 선택적으로 추가 가능:
#   key_name = "eyjo-fnf-test-key" # SSH 접속을 위한 키 페어
#   subnet_id = module.vpc2.private_subnets[0]
#   vpc_security_group_ids = [aws_security_group.vpc2_ec2_sg.id] # 보안 그룹 설정
#   iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
# }


# # Fortigate 기본 보안그룹 
# resource "aws_security_group" "vpc2_ec2_sg" {
#   name        = "ec2-security-group"
#   description = "Allow SSH and HTTP traffic"
#   vpc_id      = module.vpc2.vpc_id # VPC와 연결

#   ingress {
#     description = "Allow SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (주의: 실 운영 환경에서는 제한적으로 사용)
#   }

#   ingress {
#     description = "Allow HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (주의: 실 운영 환경에서는 제한적으로 사용)
#   }

# # ICMP(Ping) 허용
#   ingress {
#     description = "Allow ICMP (Ping)"
#     from_port   = -1   # ICMP의 모든 타입 허용
#     to_port     = -1   # ICMP의 모든 코드 허용
#     protocol    = "icmp"
#     cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용 (운영 환경에서는 제한 필요)
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1" # 모든 프로토콜 허용
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "ec2-sg"
#     Environment = "Test"
#   }
# }

