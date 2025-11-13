resource "aws_instance" "fortifate-ec2" {
  ami           = "ami-007cad54955b2bc38" # fortinet 에서 제공하는 AMI ID -> 기본 세팅 이후는 스냅샷 활용 
  instance_type = "m5.xlarge" # Attach 가능한 Interface 추가 확인

  # 새로운 방식: primary_network_interface 사용 (device_index는 자동으로 0)
  primary_network_interface {
    network_interface_id = aws_network_interface.eni_0.id
  }
  
  tags = {
    Name = "fortigate-ec2-az2a"
  }

  key_name = "eyjo-fnf-test-key" # SSH 접속을 위한 키 페어

  # 다중 ENI 환경에서는 source_dest_check 변경 무시
  lifecycle {
    ignore_changes = [source_dest_check]
  }
  
  #ENI를 별도 선언하므로, 아래 내용과는 충돌한다. 따라서 주석처리했다. 
  #subnet_id = module.vpc1.public_subnets[0]
  #vpc_security_group_ids = [aws_security_group.fortigate_sg.id] # 보안 그룹 설정
}


# # ENI_0 생성
resource "aws_network_interface" "eni_0" {
  subnet_id   = module.vpc1.public_subnets[0]
  private_ips  = ["10.0.101.100", "10.0.101.101"]
  security_groups = [aws_security_group.fortigate_sg.id] 
  source_dest_check = false 
}

# Fortigate 기본 보안그룹 
resource "aws_security_group" "fortigate_sg" {
  name        = "example-security-group"
  description = "Allow SSH and HTTP traffic"
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
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Fortigate"
    from_port   = 541
    to_port     = 541
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Fortigate"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Fortigate"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  ingress {
    description = "GENEVE - is this need"
    from_port   = 6081
    to_port     = 6081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }  


  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fortigate-sg"
    Environment = "Test"
  }
}

# 추가 ENI 보안 그룹

resource "aws_security_group" "fortigate_eni_sg" {
  name        = "fortigate_eni_sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = module.vpc1.vpc_id # VPC와 연결

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP 허용
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fortigate-eni-sg"
    Environment = "Test"
  }
}


# ENI1 생성
resource "aws_network_interface" "eni_1" {
  subnet_id       = module.vpc1.private_subnets[0]
  private_ips     = ["10.0.1.100"]    
  security_groups = [aws_security_group.fortigate_eni_sg.id] 
  source_dest_check = false 

  tags = {
    Name = "fortie-eni-1"
  }
}

# ENI2 생성
resource "aws_network_interface" "eni_2" {
  subnet_id       = module.vpc1.intra_subnets[0]
  private_ips     = ["10.0.10.100"]    
  security_groups = [aws_security_group.fortigate_eni_sg.id] 
  source_dest_check = false 

  tags = {
    Name = "fortie-eni-2"
  }
}

# ENI1를 EC2에 Attach
resource "aws_network_interface_attachment" "eni_attach" {
  instance_id          = aws_instance.fortifate-ec2.id       
  network_interface_id = aws_network_interface.eni_1.id    
  device_index         = 1                                
}

# ENI2를 EC2에 Attach
resource "aws_network_interface_attachment" "eni_attach_2" {
  instance_id          = aws_instance.fortifate-ec2.id       
  network_interface_id = aws_network_interface.eni_2.id    
  device_index         = 2                                  
}

############################################################
# VPC1 Routing - VPC2 트래픽을 TGW로
############################################################

# VPC1 intra subnet route table에 VPC2 CIDR을 TGW로 보내는 라우트 추가
resource "aws_route" "vpc1_intra_to_vpc2" {
  route_table_id         = module.vpc1.intra_route_table_ids[0]
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

# VPC1 private subnet route tables에 VPC2 CIDR을 TGW로 보내는 라우트 추가
# FortiGate에서 VPC2로 응답할 때 필요
resource "aws_route" "vpc1_private_to_vpc2" {
  count                  = length(module.vpc1.private_route_table_ids)
  route_table_id         = module.vpc1.private_route_table_ids[count.index]
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

# ############################################################
# # FortiGate #2 - AZ-2c (HA Configuration)
# ############################################################

# # FortiGate #2 EC2 Instance
# resource "aws_instance" "fortifate-ec2-az2c" {
#   ami           = "ami-007cad54955b2bc38"
#   instance_type = "m5.xlarge"

#   primary_network_interface {
#     network_interface_id = aws_network_interface.eni_0_az2c.id
#   }

#   tags = {
#     Name = "fortigate-ec2-az2c"
#   }

#   key_name = "eyjo-fnf-test-key"

#   lifecycle {
#     ignore_changes = [source_dest_check]
#   }
# }

# # ENI_0 for AZ-2c (Public Subnet)
# resource "aws_network_interface" "eni_0_az2c" {
#   subnet_id   = module.vpc1.public_subnets[1]  # AZ-2c public subnet
#   private_ips  = ["10.0.102.100", "10.0.102.101"]
#   security_groups = [aws_security_group.fortigate_sg.id]
#   source_dest_check = false

#   tags = {
#     Name = "fortigate-eni-0-az2c"
#   }
# }

# # ENI1 for AZ-2c (Private Subnet)
# resource "aws_network_interface" "eni_1_az2c" {
#   subnet_id       = module.vpc1.private_subnets[1]  # AZ-2c private subnet
#   private_ips     = ["10.0.2.100"]
#   security_groups = [aws_security_group.fortigate_eni_sg.id]
#   source_dest_check = false

#   tags = {
#     Name = "fortigate-eni-1-az2c"
#   }
# }

# # ENI2 for AZ-2c (Intra/Management Subnet)
# resource "aws_network_interface" "eni_2_az2c" {
#   subnet_id       = module.vpc1.intra_subnets[1]  # AZ-2c intra subnet
#   private_ips     = ["10.0.11.100"]
#   security_groups = [aws_security_group.fortigate_eni_sg.id]
#   source_dest_check = false

#   tags = {
#     Name = "fortigate-eni-2-az2c"
#   }
# }

# # ENI1를 EC2에 Attach (AZ-2c)
# resource "aws_network_interface_attachment" "eni_attach_az2c" {
#   instance_id          = aws_instance.fortifate-ec2-az2c.id
#   network_interface_id = aws_network_interface.eni_1_az2c.id
#   device_index         = 1
# }

# # ENI2를 EC2에 Attach (AZ-2c)
# resource "aws_network_interface_attachment" "eni_attach_2_az2c" {
#   instance_id          = aws_instance.fortifate-ec2-az2c.id
#   network_interface_id = aws_network_interface.eni_2_az2c.id
#   device_index         = 2
# }

# ## fortigate 접속용 정보 ##
# output "instance_public_ip" {
#   description = "The public IP address of the instance (AZ-2a)"
#   value       = aws_instance.fortifate-ec2.public_ip
# }

# output "instance_instance_id" {
#   description = "fortigate initialized password (AZ-2a)"
#   value       = aws_instance.fortifate-ec2.id
# }

# output "instance_public_ip_az2c" {
#   description = "The public IP address of the instance (AZ-2c)"
#   value       = aws_instance.fortifate-ec2-az2c.public_ip
# }

# output "instance_instance_id_az2c" {
#   description = "fortigate initialized password (AZ-2c)"
#   value       = aws_instance.fortifate-ec2-az2c.id
# }