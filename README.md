# Parnas Vserver Infrastructure with Fortigate

## 📋 개요

AWS 기반 Fortigate 방화벽을 통한 엔터프라이즈급 멀티 도메인 웹 서비스 인프라

### 🎯 핵심 특징
- **중앙집중식 보안**: Fortigate 방화벽을 통한 모든 트래픽 제어
- **멀티 도메인 지원**: 단일 인프라로 여러 도메인 서비스 제공
- **호스트헤더 라우팅**: REST API Gateway 기반 지능형 트래픽 분기
- **계층화된 보안**: 4단계 보안 계층으로 방어 심도 구현

## 🏗️ 아키텍처

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Internet  │───▶│External NLB │───▶│  Fortigate  │───▶│Internal NLB │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                           │                     │
                                      Secondary IP           Port 80/443
                                      10.0.101.101                │
                                                                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────────┐
│  Backend A  │◀───│  Backend B  │◀───│       REST API Gateway         │
└─────────────┘    └─────────────┘    └─────────────────────────────────┘
      ▲                   ▲                           │
api.example.com    web.example.com           Host Header Routing
```

### 트래픽 플로우
1. **External NLB**: 인터넷 트래픽 수신 및 분산
2. **Fortigate**: Secondary IP(10.0.101.101)로 보안 필터링
3. **Internal NLB**: 내부 네트워크 로드밸런싱  
4. **REST API Gateway**: 호스트헤더 기반 백엔드 라우팅

## 🔧 인프라 구성

### 네트워크 아키텍처
```
VPC1 (10.0.0.0/16)
├── Public Subnets
│   ├── 10.0.101.0/24 (AZ-1a) - External NLB, Fortigate
│   └── 10.0.102.0/24 (AZ-1c) - External NLB
├── Private Subnets  
│   ├── 10.0.1.0/24 (AZ-1a) - Internal NLB, API Gateway VPC Endpoint
│   └── 10.0.2.0/24 (AZ-1c) - Internal NLB, API Gateway VPC Endpoint
└── Intra Subnets
    ├── 10.0.10.0/24 (AZ-1a) - Fortigate Management
    └── 10.0.20.0/24 (AZ-1c) - Reserved
```

### 핵심 컴포넌트

#### 🔥 Fortigate 방화벽
- **인스턴스**: m5.xlarge (4 vCPU, 16GB RAM)
- **인터페이스 구성**:
  - `port1`: 10.0.101.100 (Primary), **10.0.101.101 (Secondary)** ← 핵심
  - `port2`: 10.0.1.100 (Internal)
  - `port3`: 10.0.10.100 (Management)

#### ⚖️ Load Balancer 구성
- **External NLB**: 
  - 인터넷 게이트웨이 연결
  - 80, 443 포트 리스닝
  - Fortigate Secondary IP로 전달
- **Internal NLB**:
  - Private 서브넷 배치
  - API Gateway VPC Endpoint 연결

#### 🌐 REST API Gateway
- **타입**: Private REST API Gateway
- **연결**: VPC Endpoint를 통한 내부 통신
- **기능**: 호스트헤더 보존 및 백엔드 프록시

## 📁 파일 구조

```
├── README.md                           # 📖 프로젝트 가이드 (이 파일)
├── FORTIGATE-CONFIGURATION.md          # 🔥 Fortigate 설정 상세 가이드
├── vpc.tf                              # 🌐 VPC 및 네트워크 기본 구성
├── vpc1-fortigate-ec2.tf               # 🔥 Fortigate EC2 인스턴스 및 ENI
├── vpc1-extenral-nlb-internal-nlb.tf   # ⚖️ 로드밸런서 구성
├── vpc1-rest-api-gateway-private.tf    # 🌐 REST API Gateway 설정
├── vpc_endpoint.tf                     # 🔗 VPC Endpoint 구성
├── ssm-iam.tf                          # 🔐 IAM 역할 및 정책
├── trasitgateway.tf                    # 🌉 Transit Gateway (선택사항)
├── variables.tf                        # ⚙️ 변수 정의
├── output.tf                           # 📤 출력 값 정의
└── terraform.tfstate*                  # 📊 Terraform 상태 파일
```

## 🚀 배포 가이드

### 사전 요구사항
```bash
# 필수 도구
terraform >= 1.0
aws-cli >= 2.0
jq (선택사항)

# AWS 권한
EC2, VPC, ELB, API Gateway, IAM 권한 필요
```

### 📋 배포 단계

#### 1️⃣ 환경 준비
```bash
# 리포지토리 클론
git clone <repository-url>
cd Parnas-Vserver-Infra-Fortigate

# AWS 인증 확인
aws sts get-caller-identity
```

#### 2️⃣ Terraform 배포
```bash
# Terraform 초기화
terraform init

# 배포 계획 확인
terraform plan

# 인프라 배포
terraform apply
```

#### 3️⃣ Fortigate 설정
```bash
# Fortigate 인스턴스 접속 정보 확인
terraform output instance_public_ip
terraform output instance_instance_id

# Fortigate 설정 수행
# 상세 내용은 FORTIGATE-CONFIGURATION.md 참조
```

#### 4️⃣ VPC Endpoint 연결 (🚨 중요!)
```bash
# 1. VPC Endpoint 정보 확인
API_GW_ENDPOINT_ID=$(terraform output -raw api_gateway_vpc_endpoint_id)
TARGET_GROUP_ARN=$(terraform output -raw internal_nlb_target_group_arn)

# 2. VPC Endpoint의 ENI ID 확인
ENI_IDS=$(aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids $API_GW_ENDPOINT_ID \
  --query 'VpcEndpoints[0].NetworkInterfaceIds' \
  --output text)

# 3. 각 ENI의 Private IP 확인
for eni_id in $ENI_IDS; do
  PRIVATE_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids $eni_id \
    --query 'NetworkInterfaces[0].PrivateIpAddress' \
    --output text)
  echo "ENI: $eni_id, IP: $PRIVATE_IP"
done

# 4. Target Group에 VPC Endpoint IP 등록
aws elbv2 register-targets \
  --target-group-arn $TARGET_GROUP_ARN \
  --targets Id=<IP-1>,Port=443 Id=<IP-2>,Port=443
```

#### 5️⃣ 연결 테스트
```bash
# API Gateway URL 확인
terraform output rest_api_gateway_url

# 연결 테스트 (Fortigate 설정 완료 후)
curl -H "Host: api.example.com" http://<external-nlb-dns>/health
```

## 🔧 운영 가이드

### 주요 출력 정보
```bash
# 배포 후 확인할 주요 정보
terraform output external_nlb_dns          # External NLB 도메인
terraform output internal_nlb_dns          # Internal NLB 도메인  
terraform output rest_api_gateway_url      # API Gateway URL
terraform output instance_public_ip        # Fortigate 접속 IP
```

### 🔍 상태 모니터링
```bash
# NLB 타겟 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw internal_nlb_target_group_arn)

# API Gateway 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=fortigate-proxy-rest-api
```

### 🚨 문제 해결

#### 트래픽이 전달되지 않는 경우
```bash
# 1. Fortigate Secondary IP 설정 확인
ssh admin@<fortigate-ip>
show system interface port1

# 2. NLB 타겟 상태 확인
aws elbv2 describe-target-health --target-group-arn <arn>

# 3. 보안 그룹 확인
aws ec2 describe-security-groups --group-ids <sg-id>
```

#### API Gateway 연결 실패
```bash
# VPC Endpoint 상태 확인
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids <endpoint-id>

# API Gateway 로그 확인
aws logs filter-log-events \
  --log-group-name "/aws/apigateway/fortigate-rest-api"
```

## 🔐 보안 설정

### Fortigate 보안 정책
- ✅ **포트 제한**: 80, 443 포트만 허용
- ✅ **DDoS 보호**: 자동 차단 기능 활성화
- ✅ **IPS**: 침입 방지 시스템 활성화  
- ✅ **로깅**: 모든 트래픽 로그 수집

### AWS 보안 그룹
```bash
# Fortigate 보안 그룹 (예시)
Inbound:
  - 22/tcp from 0.0.0.0/0        # SSH (제한 권장)
  - 80/tcp from 0.0.0.0/0        # HTTP
  - 443/tcp from 0.0.0.0/0       # HTTPS
  - 541/tcp from 0.0.0.0/0       # Fortigate 관리
  - ICMP from 0.0.0.0/0          # Ping

# API Gateway Endpoint 보안 그룹
Inbound:
  - 443/tcp from VPC CIDR        # HTTPS from VPC
```

## 📊 모니터링 및 알람

### 주요 메트릭
```bash
# CloudWatch 메트릭 설정
- AWS/ApplicationELB: TargetResponseTime, HTTPCode_Target_2XX_Count
- AWS/ApiGateway: Count, Latency, 4XXError, 5XXError  
- AWS/EC2: CPUUtilization, NetworkIn, NetworkOut (Fortigate)
```

### 알람 설정 예시
```bash
# API Gateway 에러율 알람
aws cloudwatch put-metric-alarm \
  --alarm-name "API-Gateway-High-Error-Rate" \
  --metric-name 4XXError \
  --namespace AWS/ApiGateway \
  --statistic Sum \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

## 💰 비용 최적화

### 월간 예상 비용 (서울 리전)
```
🔥 Fortigate EC2 (m5.xlarge):     ~$140/월
⚖️ External NLB:                 ~$20/월  
⚖️ Internal NLB:                 ~$20/월
🌐 API Gateway:                  ~$3.50/10만 요청
🔗 VPC Endpoint:                 ~$7/월
📊 Data Transfer:                변동적

총 예상 비용: ~$190-250/월 (트래픽에 따라)
```

### 비용 절약 방법
- 🏷️ **Reserved Instance**: Fortigate EC2 1년 예약시 30% 절약
- 📦 **Spot Instance**: 개발환경에서는 Spot Instance 활용
- 🕒 **스케줄링**: 개발환경 자동 중지/시작

## 🔄 업그레이드 및 유지보수

### Fortigate 업그레이드
```bash
# 1. 스냅샷 생성
aws ec2 create-snapshot \
  --volume-id <fortigate-volume-id> \
  --description "Pre-upgrade snapshot"

# 2. 설정 백업
ssh admin@<fortigate-ip>
execute backup config flash backup_$(date +%Y%m%d)

# 3. 업그레이드 수행 (Fortigate 웹 GUI)
```

### Terraform 업그레이드
```bash
# 상태 파일 백업
cp terraform.tfstate terraform.tfstate.backup

# 버전 호환성 확인
terraform version
terraform providers

# 단계적 적용
terraform plan -target=module.specific
```

## 🛠️ 고급 설정

### 다중 환경 지원
```bash
# 환경별 변수 파일 생성
terraform.tfvars.dev
terraform.tfvars.staging  
terraform.tfvars.prod

# 환경별 배포
terraform apply -var-file=terraform.tfvars.prod
```

### 백업 자동화
```bash
# Lambda 함수로 정기 백업 설정
- Fortigate 설정 백업
- Terraform 상태 파일 S3 백업
- CloudWatch Events 스케줄링
```

## 🆘 지원 및 문의

### 📞 긴급 연락처
- **인프라 팀**: infrastructure@company.com
- **보안 팀**: security@company.com  
- **24시간 온콜**: +82-XX-XXXX-XXXX

### 📚 추가 문서
- [Fortigate 설정 가이드](./FORTIGATE-CONFIGURATION.md)
- [네트워크 다이어그램](./docs/network-diagram.png)
- [보안 정책 문서](./docs/security-policy.md)

### 🐛 이슈 리포팅
```bash
# 이슈 템플릿
1. 환경 정보 (dev/staging/prod)
2. 발생 시간
3. 에러 메시지  
4. 재현 단계
5. 기대 결과 vs 실제 결과
```

---

## 📋 체크리스트

### 배포 완료 체크리스트
- [ ] Terraform apply 성공
- [ ] Fortigate 인스턴스 접근 가능
- [ ] Secondary IP (10.0.101.101) 설정 완료
- [ ] 방화벽 정책 적용 완료
- [ ] VPC Endpoint Target 등록 완료
- [ ] External NLB Health Check 통과
- [ ] Internal NLB Health Check 통과
- [ ] API Gateway 응답 확인
- [ ] 도메인별 라우팅 테스트 완료
- [ ] 모니터링 대시보드 설정
- [ ] 알람 설정 완료

### 운영 준비 체크리스트  
- [ ] 백업 정책 수립
- [ ] 재해복구 계획 수립
- [ ] 운영 매뉴얼 작성
- [ ] 팀 교육 완료
- [ ] 연락처 정보 업데이트

---

**📅 최종 업데이트**: 2025-08-19  
**🏷️ 버전**: 2.0  
**👥 작성자**: Infrastructure Team  
**📝 라이선스**: MIT
