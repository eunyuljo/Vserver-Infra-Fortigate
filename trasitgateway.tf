# 1. TGW 생성 (기본 라우팅 테이블 비활성화)
resource "aws_ec2_transit_gateway" "tgw" {
  description = "Test Transit Gateway"

  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "Test-TGW"
  }
}

# 2. TGW Route Table 생성 (명시적 테이블)
resource "aws_ec2_transit_gateway_route_table" "tgw_route_table" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id

  tags = {
    Name = "TGW-Custom-Route-Table"
  }
}

# 3. VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc1_attachment" {
  subnet_ids            = [tolist(module.vpc1.intra_subnets)[0], 
                           tolist(module.vpc1.intra_subnets)[1]]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc1.vpc_id

  tags = {
    Name = "VPC1-TGW-Attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc2_attachment" {
  subnet_ids         = module.vpc2.intra_subnets
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc2.vpc_id

  tags = {
    Name = "VPC2-TGW-Attachment"
  }
}

# 4. Attachments를 명시적 Route Table에 연결
resource "aws_ec2_transit_gateway_route_table_association" "vpc1_assoc" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc1_attachment.id
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc2_assoc" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc2_attachment.id
}

# 5. 라우팅 전파 (Route Propagation)
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc1_propagation" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc1_attachment.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpc2_propagation" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc2_attachment.id
}

# 6. 명시적 라우팅 - VPC2의 트래픽을 VPC1로
resource "aws_ec2_transit_gateway_route" "route_0_0_0_0_to_vpc1" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc1_attachment.id
}
