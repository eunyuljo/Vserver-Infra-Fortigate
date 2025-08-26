# Parnas Vserver Infrastructure with Fortigate

## 📋 개요

AWS 기반 Fortigate 방화벽과 Transit Gateway를 활용한 멀티 VPC 보안 인프라

### 🎯 핵심 특징
- **중앙집중식 보안**: Fortigate 방화벽을 통한 모든 트래픽 제어
- **멀티 VPC 지원**: Transit Gateway를 통한 VPC간 연결
- **로드밸런싱**: External NLB + Internal ALB 조합
- **계층화된 보안**: Fortigate + WAF + Security Groups 다중 보안

## 🏗️ 아키텍처

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Internet  │───▶│External NLB │───▶│  Fortigate  │───▶│Internal ALB │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                           │                     │
                                      Secondary IP           Port 80/443
                                      10.0.101.101                │
                                                                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────────┐
│    VPC2     │◀───│  Backend    │◀───│         Internal ALB            │
│  Services   │    │  Services   │    └─────────────────────────────────┘
└─────────────┘    └─────────────┘                    │
      ▲                   ▲                Transit Gateway
   TGW 연결            VPC1 Services           연결 지원
```

### 트래픽 플로우
1. **External NLB**: 인터넷 트래픽 수신 및 분산
2. **Fortigate**: Secondary IP(10.0.101.101)로 보안 필터링 및 정책 적용
3. **Internal ALB**: 내부 애플리케이션 로드밸런싱  
4. **Backend Services**: VPC1/VPC2 내부 서비스들로 라우팅
5. **Transit Gateway**: VPC간 통신 및 연결성 제공

## 🔧 인프라 구성

### 네트워크 아키텍처
```
VPC1 (10.0.0.0/16) - eyjo-parnas-sec-vpc1
├── Public Subnets
│   ├── 10.0.101.0/24 (AZ-2a) - External NLB, Fortigate
│   ├── 10.0.102.0/24 (AZ-2c) - External NLB
│   ├── 10.0.103.0/24 (AZ-2a) - Reserved
│   └── 10.0.104.0/24 (AZ-2c) - Reserved
├── Private Subnets  
│   ├── 10.0.1.0/24 (AZ-2a) - Internal ALB, Backend Services
│   ├── 10.0.2.0/24 (AZ-2c) - Internal ALB, Backend Services
│   ├── 10.0.3.0/24 (AZ-2a) - Reserved
│   ├── 10.0.4.0/24 (AZ-2c) - TGW 연결용
│   ├── 10.0.5.0/24 (AZ-2a) - TGW 연결용
│   └── 10.0.6.0/24 (AZ-2c) - TGW 연결용
└── Intra Subnets
    ├── 10.0.10.0/24 (AZ-2a) - Management/Internal
    ├── 10.0.11.0/24 (AZ-2c) - Management/Internal
    └── 10.0.12.0/24 (AZ-2a) - Reserved

VPC2 (10.1.0.0/16) - eyjo-parnas-sec-vpc2
├── Public Subnets
│   ├── 10.1.101.0/24 (AZ-2a) - Secondary Services
│   ├── 10.1.102.0/24 (AZ-2b) - Secondary Services
│   └── 10.1.103.0/24 (AZ-2c) - Secondary Services
├── Private Subnets
│   ├── 10.1.1.0/24 (AZ-2a) - Private Services
│   ├── 10.1.2.0/24 (AZ-2b) - Private Services
│   └── 10.1.3.0/24 (AZ-2c) - Private Services
└── Intra Subnets
    ├── 10.1.10.0/24 (AZ-2a) - TGW 연결
    ├── 10.1.11.0/24 (AZ-2b) - TGW 연결
    └── 10.1.12.0/24 (AZ-2c) - TGW 연결
```

### 핵심 컴포넌트

#### 🔥 Fortigate 방화벽
- **인스턴스**: m5.xlarge (4 vCPU, 16GB RAM)
- **인터페이스 구성**:
  - `port1`: 10.0.101.100 (Primary), **10.0.101.101 (Secondary)** ← 핵심
  - Secondary IP로 트래픽 수신 및 처리
- **보안그룹**: SSH(22), HTTP(80), HTTPS(443), ICMP 허용

#### ⚖️ Load Balancer 구성
- **External NLB**: 
  - 인터넷 게이트웨이 연결
  - 80, 443 포트 리스닝
  - Fortigate Secondary IP로 전달
- **Internal ALB**:
  - Private 서브넷 배치
  - 백엔드 서비스 연결

#### 🔒 WAF 및 보안
- **Private WAF**: 웹 애플리케이션 방화벽 설정
- **VPC Endpoint**: 내부 통신을 위한 프라이빗 연결

#### 🌉 Transit Gateway
- **VPC 간 연결**: VPC1과 VPC2 연결
- **라우팅**: 중앙집중식 네트워크 관리

## 📁 파일 구조

```
├── README.md                           # 📖 프로젝트 가이드 (이 파일)
├── FORTIGATE-CONFIGURATION.md          # 🔥 Fortigate 설정 상세 가이드
├── vpc.tf                              # 🌐 VPC 및 네트워크 기본 구성
├── vpc1-fortigate-ec2.tf               # 🔥 Fortigate EC2 인스턴스 및 ENI
├── vpc1-extenral-nlb-internal-nlb.tf   # ⚖️ External NLB 구성
├── vpc1-private-waf.tf                  # 🔒 WAF 및 Private 보안 설정
├── vpc1-internal-alb.tf                 # ⚖️ Internal ALB 구성
├── vpc_endpoint.tf                     # 🔗 VPC Endpoint 구성
├── vpc1-ec2.tf                         # 💻 VPC1 EC2 인스턴스
├── vpc1-ec2-2.tf                       # 💻 VPC1 추가 EC2 인스턴스
├── vpc2-ec2.tf                         # 💻 VPC2 EC2 인스턴스
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

#### 4️⃣ ALB 및 백엔드 서비스 연결
```bash
# 1. Internal ALB 정보 확인
INTERNAL_ALB_DNS=$(terraform output -raw internal_alb_dns)
INTERNAL_ALB_ZONE_ID=$(terraform output -raw internal_alb_zone_id)

# 2. VPC1 EC2 인스턴스 정보 확인
VPC1_EC2_IP=$(terraform output -raw vpc1_ec2_private_ip)

# 3. 백엔드 서비스 상태 확인
echo "Internal ALB DNS: $INTERNAL_ALB_DNS"
echo "VPC1 EC2 IP: $VPC1_EC2_IP"
```

#### 5️⃣ 연결 테스트
```bash
# External NLB DNS 확인
EXTERNAL_NLB_DNS=$(terraform output -raw external_nlb_dns)

# 연결 테스트 (Fortigate 설정 완료 후)
curl http://$EXTERNAL_NLB_DNS/
curl https://$EXTERNAL_NLB_DNS/
```

## 🔧 운영 가이드

### 주요 출력 정보
```bash
# 배포 후 확인할 주요 정보
terraform output external_nlb_dns          # External NLB 도메인
terraform output internal_alb_dns          # Internal ALB 도메인  
terraform output internal_alb_zone_id      # Internal ALB Zone ID
terraform output vpc1_ec2_private_ip       # VPC1 EC2 Private IP
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
⚖️ Internal ALB:                 ~$20/월
💻 EC2 Instances (VPC1/VPC2):    ~$50/월
🌉 Transit Gateway:              ~$40/월
🔗 VPC Endpoint:                 ~$7/월
📊 Data Transfer:                변동적

총 예상 비용: ~$280-350/월 (트래픽에 따라)
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

**📅 최종 업데이트**: 2025-08-26  
**🏷️ 버전**: 2.1  
**👥 작성자**: Infrastructure Team  
**📝 라이선스**: MIT
