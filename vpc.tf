provider "aws" {
  region = "ap-northeast-2"
}

module "vpc1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eyjo-parnas-sec-vpc1"
  cidr = "10.0.0.0/16"

  azs                     = ["ap-northeast-2a", "ap-northeast-2c"]

  public_subnets          = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
  public_subnet_names     = ["eyjo-parnas-vpc1-public-101","eyjo-parnas-vpc1-public-102","eyjo-parnas-vpc1-public-103","eyjo-parnas-vpc1-public-104"]
  map_public_ip_on_launch = true

  private_subnets         = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  private_subnet_names    = ["eyjo-parnas-vpc1-private-1","eyjo-parnas-vpc1-private-2","eyjo-parnas-vpc1-private-3",
                          "eyjo-parnas-vpc1-private-4","eyjo-parnas-vpc1-private-5","eyjo-parnas-vpc1-private-6"]

  # tgw 용 
  intra_subnets           =  ["10.0.10.0/24","10.0.11.0/24","10.0.12.0/24","10.0.13.0/24"]
  intra_subnet_names      = ["eyjo-parnas-vpc1-tgw-a","eyjo-parnas-vpc1-tgw-c","eyjo-parnas-vpc1-intra-1","eyjo-parnas-vpc1-intra-2"]
  #각 VPC 환경은 NAT를 사용하지 않고 FW 을 통해 경유하도록 구성한다.
  #enable_nat_gateway = true
  #single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "Test"
    Project     = "Test"
  }
}


module "vpc2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eyjo-parnas-sec-vpc2"
  cidr = "10.1.0.0/16"

  azs                     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  public_subnets          = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
  public_subnet_names     = ["eyjo-parnas-vpc2-public-101","eyjo-parnas-vpc2-public-102","eyjo-parnas-vpc2-public-103"]
  map_public_ip_on_launch = true
  private_subnets         = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_names    = ["eyjo-parnas-vpc2-private-1","eyjo-parnas-vpc2-private-2","eyjo-parnas-vpc2-private-3"]
  # tgw 용 
  intra_subnets           =  ["10.1.10.0/24","10.1.11.0/24","10.1.12.0/24"]
  intra_subnet_names      = ["eyjo-parnas-vpc2-intra-1","eyjo-parnas-vpc2-intra-2","eyjo-parnas-vpc2-intra-3"]
  #각 VPC 환경은 NAT를 사용하지 않고 FW 을 통해 경유하도록 구성한다.
  #enable_nat_gateway       = true
  #single_nat_gateway       = true

  enable_dns_hostnames    = true
  enable_dns_support      = true

  tags = {
    Environment = "Test"
    Project     = "Test"
  }
}



