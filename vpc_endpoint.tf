# VPC1 Endpoint

# ssm endpoint - vpc1

resource "aws_security_group" "ssm" {
  vpc_id = module.vpc1.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 필요에 따라 IP 제한을 설정
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssm-sg-vpc1"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = module.vpc1.vpc_id
  service_name       = "com.amazonaws.ap-northeast-2.ssm"  
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc1.private_subnets[0]] 
  security_group_ids = [aws_security_group.ssm.id]
  private_dns_enabled = true

  tags = {
    Name = "ssm-endpoint-vpc1"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = module.vpc1.vpc_id
  service_name        = "com.amazonaws.ap-northeast-2.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids          = [module.vpc1.private_subnets[0]]
  security_group_ids  = [aws_security_group.ssm.id]
  private_dns_enabled = true

  tags = {
    Name = "ssm-messages-endpoint-vpc1"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id             = module.vpc1.vpc_id
  service_name       = "com.amazonaws.ap-northeast-2.ec2messages" 
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc1.private_subnets[0]]
  security_group_ids = [aws_security_group.ssm.id]
  private_dns_enabled = true

  tags = {
    Name = "ec2-messages-endpoint-vpc1"
  }
}

# ssm endpoint - vpc2

resource "aws_security_group" "ssm_vpc2" {
  vpc_id = module.vpc2.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 필요에 따라 IP 제한을 설정
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssm-sg-vpc2"
  }
}


resource "aws_vpc_endpoint" "ssm_vpc2" {
  vpc_id             = module.vpc2.vpc_id
  service_name       = "com.amazonaws.ap-northeast-2.ssm"  
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc2.private_subnets[0]] 
  security_group_ids = [aws_security_group.ssm_vpc2.id]
  private_dns_enabled = true

  tags = {
    Name = "ssm-endpoint-vpc2"
  }
}

resource "aws_vpc_endpoint" "ssmmessages_vpc2" {
  vpc_id              = module.vpc2.vpc_id
  service_name        = "com.amazonaws.ap-northeast-2.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids          = [module.vpc2.private_subnets[0]]
  security_group_ids  = [aws_security_group.ssm_vpc2.id]
  private_dns_enabled = true

  tags = {
    Name = "ssm-messages-endpoint-vpc2"
  }
}

resource "aws_vpc_endpoint" "ec2messages_vpc2" {
  vpc_id             = module.vpc2.vpc_id
  service_name       = "com.amazonaws.ap-northeast-2.ec2messages" 
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc2.private_subnets[0]]
  security_group_ids = [aws_security_group.ssm_vpc2.id]
  private_dns_enabled = true

  tags = {
    Name = "ec2-messages-endpoint-vpc2"
  }
}

