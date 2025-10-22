# Parnas Vserver Infrastructure with FortiGate

## 📋 개요

AWS 기반 FortiGate 방화벽과 Transit Gateway를 활용한 멀티 VPC 보안 인프라
도메인 기반 라우팅 및 Nginx 프록시 레이어를 통한 확장 가능한 아키텍처

### 🎯 핵심 특징
- **중앙집중식 보안**: FortiGate 방화벽을 통한 모든 트래픽 제어
- **멀티 VPC 지원**: Transit Gateway를 통한 VPC 간 연결
- **도메인 기반 라우팅**: Host Header를 활용한 멀티 도메인 지원 (*.country-mouse.net)
- **계층화된 로드밸런싱**: External NLB → Internal ALB → Internal NLB → Nginx Proxy
- **확장 가능한 프록시**: Nginx 프록시 레이어 (향후 WAF 교체 가능)

## 🏗️ 아키텍처

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                               INTERNET                                       │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │
                                    │ HTTP/HTTPS (80/443)
                                    │
                       ┌────────────▼────────────┐
                       │   External NLB (Public) │
                       │   - AZ 2a, 2c           │
                       └────────────┬────────────┘
                                    │
                                    │ Target: 10.0.101.101
                                    │
                 ┌──────────────────▼──────────────────┐
                 │      FortiGate EC2 Instance         │
                 │  - Primary IP: 10.0.101.100         │
                 │  - Secondary IP: 10.0.101.101 ◄──── NLB Target
                 │  - port1 (External): 10.0.101.x     │
                 │  - port2 (Internal): 10.0.1.100     │
                 │  - port3 (Mgmt): 10.0.10.100        │
                 └──────────────────┬──────────────────┘
                                    │
                                    │ Forwarded to Internal
                                    │
                       ┌────────────▼────────────┐
                       │  Internal ALB (Private) │
                       │  - AZ 2a, 2c            │
                       │  - Port 80/443          │
                       └────────────┬────────────┘
                                    │
                                    │ Host-based Routing
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
     ┌─────▼─────┐          ┌───────▼──────┐        ┌──────▼──────┐
     │ api.      │          │ web.         │   ...  │ admin.      │
     │ country-  │          │ country-     │        │ country-    │
     │ mouse.net │          │ mouse.net    │        │ mouse.net   │
     └─────┬─────┘          └───────┬──────┘        └──────┬──────┘
           │                        │                      │
           └────────────────────────┼──────────────────────┘
                                    │
                                    │ All domains
                                    │
                       ┌────────────▼────────────┐
                       │ Internal NLB (Private)  │
                       │   nlb-internal-waf      │
                       │   - Port 80 (TCP)       │
                       └────────────┬────────────┘
                                    │
                       ┌────────────┴────────────┐
                       │                         │
             ┌─────────▼─────────┐     ┌─────────▼─────────┐
             │ Nginx Proxy #1    │     │ Nginx Proxy #2    │
             │ - AZ: 2a          │     │ - AZ: 2c          │
             │ - Host 보존       │     │ - Host 보존       │
             └─────────┬─────────┘     └─────────┬─────────┘
                       │                         │
             ┌─────────▼─────────┐     ┌─────────▼─────────┐
             │ Backend EC2 #1    │     │ Backend EC2 #2    │
             │ - AZ: 2a          │     │ - AZ: 2c          │
             └───────────────────┘     └───────────────────┘
```

### 트래픽 플로우
1. **External NLB**: 인터넷 트래픽 수신 및 분산 (포트 80/443)
2. **FortiGate**: Secondary IP(10.0.101.101)로 보안 필터링 및 정책 적용
3. **Internal ALB**: Host Header 기반 도메인 라우팅 (api/web/app/admin.country-mouse.net)
4. **Internal NLB**: Nginx 프록시 인스턴스로 트래픽 분산
5. **Nginx Proxy**: Host Header 보존하며 백엔드로 프록시
6. **Backend Services**: VPC1 내부 서비스들로 최종 라우팅
7. **Transit Gateway**: VPC 간 통신 및 중앙집중식 egress 제공

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

#### 🔥 FortiGate 방화벽
- **인스턴스**: m5.xlarge (4 vCPU, 16GB RAM)
- **인터페이스 구성**:
  - `port1` (External): 10.0.101.100 (Primary), **10.0.101.101 (Secondary)** ← 핵심
  - `port2` (Internal): 10.0.1.100
  - `port3` (Management): 10.0.10.100
- **역할**: 모든 인바운드 트래픽의 보안 검사 및 필터링
- **보안그룹**: SSH(22), HTTP(80), HTTPS(443), FortiGate 관리 포트, ICMP 허용

#### ⚖️ Load Balancer 구성
- **External NLB (Public)**:
  - Public 서브넷 배치 (AZ 2a, 2c)
  - 80, 443 포트 리스닝
  - FortiGate Secondary IP (10.0.101.101)로 전달

- **Internal ALB (Private)**:
  - Private 서브넷 배치 (AZ 2a, 2c)
  - **Host Header 기반 라우팅**:
    - `api.country-mouse.net` → API Target Group
    - `web.country-mouse.net` → Web Target Group
    - `app.country-mouse.net` → App Target Group
    - `admin.country-mouse.net` → Admin Target Group
  - SSL/TLS 종료 (ACM 인증서 사용)

- **Internal NLB (Private - WAF용)**:
  - Private 서브넷 배치 (AZ 2a, 2c)
  - TCP 프로토콜 (포트 80)
  - Nginx 프록시 인스턴스로 트래픽 분산
  - Cross-AZ 로드밸런싱: Disabled

#### 🔄 Nginx Proxy Layer
- **인스턴스**: Ubuntu 24.04, t3.micro × 2 (AZ 2a, 2c)
- **역할**:
  - HTTP 프록시 (향후 Third-party WAF 교체 가능)
  - Host Header 보존 및 전달
  - 백엔드 서비스로 트래픽 프록시
- **기능**:
  - `/health` 헬스체크 엔드포인트
  - X-Forwarded-* 헤더 전달
  - 액세스 로그 수집
- **자동 구성**: User Data로 nginx 자동 설치 및 설정

#### 🌉 Transit Gateway
- **VPC 간 연결**: VPC1과 VPC2 연결
- **중앙집중식 Egress**: VPC2의 모든 인터넷 트래픽은 VPC1의 FortiGate 경유
- **라우팅**:
  - Default Route (0.0.0.0/0) → VPC1
  - VPC1 ↔ VPC2 상호 연결 (Propagation)
- **설정**: Default Route Tables 비활성화, Custom Route Table 사용

## 📁 파일 구조

```
├── README.md                           # 📖 프로젝트 가이드 (이 파일)
├── FORTIGATE-CONFIGURATION.md          # 🔥 FortiGate 설정 상세 가이드
├── vpc.tf                              # 🌐 VPC 및 네트워크 기본 구성
├── vpc1-fortigate-ec2.tf               # 🔥 FortiGate EC2 인스턴스 및 ENI
├── vpc1-extenral-nlb-internal-nlb.tf   # ⚖️ External NLB 구성
├── vpc1-internal-alb.tf                # ⚖️ Internal ALB + 도메인 기반 라우팅
├── vpc1-internal-nlb-waf.tf            # 🔄 Internal NLB + Nginx Proxy 구성
├── vpc1-private-waf.tf                 # 🔒 WAF 설정 (주석 처리)
├── vpc_endpoint.tf                     # 🔗 VPC Endpoint 구성 (SSM)
├── vpc1-ec2.tf                         # 💻 VPC1 EC2 인스턴스 #1
├── vpc1-ec2-2.tf                       # 💻 VPC1 EC2 인스턴스 #2
├── vpc2-ec2.tf                         # 💻 VPC2 EC2 인스턴스
├── ssm-iam.tf                          # 🔐 IAM 역할 및 정책 (SSM)
├── trasitgateway.tf                    # 🌉 Transit Gateway 구성
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

#### 3️⃣ FortiGate 설정
```bash
# FortiGate 인스턴스 접속 정보 확인
terraform output instance_public_ip
terraform output instance_instance_id

# FortiGate 설정 수행
# 상세 내용은 FORTIGATE-CONFIGURATION.md 참조
```

#### 4️⃣ 도메인 기반 라우팅 설정
```bash
# 1. Internal ALB 정보 확인
INTERNAL_ALB_DNS=$(terraform output -raw internal_alb_dns)
echo "Internal ALB DNS: $INTERNAL_ALB_DNS"

# 2. Internal NLB (WAF/Proxy용) 정보 확인
NLB_WAF_DNS=$(terraform output -raw nlb_waf_dns)
echo "Internal NLB (Proxy) DNS: $NLB_WAF_DNS"

# 3. Nginx Proxy 인스턴스 확인
# proxy-instance-1, proxy-instance-2가 자동으로 생성됨
# User Data로 nginx가 자동 설치 및 구성됨
```

#### 5️⃣ 도메인 DNS 설정
```bash
# 각 도메인을 External NLB로 연결
# DNS 레코드 (Route53 또는 외부 DNS 서버):
# api.country-mouse.net    → CNAME → [External NLB DNS]
# web.country-mouse.net    → CNAME → [External NLB DNS]
# app.country-mouse.net    → CNAME → [External NLB DNS]
# admin.country-mouse.net  → CNAME → [External NLB DNS]
```

#### 6️⃣ 연결 테스트
```bash
# External NLB DNS 확인
EXTERNAL_NLB_DNS=$(terraform output -raw external_nlb_dns)

# 도메인별 테스트 (FortiGate 설정 완료 후)
curl -H "Host: api.country-mouse.net" http://$EXTERNAL_NLB_DNS/
curl -H "Host: web.country-mouse.net" http://$EXTERNAL_NLB_DNS/
curl -H "Host: app.country-mouse.net" http://$EXTERNAL_NLB_DNS/
curl -H "Host: admin.country-mouse.net" http://$EXTERNAL_NLB_DNS/

# 실제 도메인으로 테스트 (DNS 설정 후)
curl http://api.country-mouse.net/
curl http://web.country-mouse.net/
```

## 🔧 운영 가이드

### 주요 출력 정보
```bash
# 배포 후 확인할 주요 정보
terraform output external_nlb_dns          # External NLB DNS
terraform output internal_alb_dns          # Internal ALB DNS
terraform output nlb_waf_dns               # Internal NLB (Proxy) DNS
terraform output nlb_waf_arn               # Internal NLB ARN
terraform output instance_public_ip        # FortiGate Public IP
terraform output instance_instance_id      # FortiGate Instance ID
```

### 🔍 상태 모니터링
```bash
# External NLB 타겟 상태 확인 (FortiGate)
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw external_nlb_target_group_arn)

# Internal NLB 타겟 상태 확인 (Nginx Proxy)
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw nlb_waf_tg_arn)

# Internal ALB 타겟 그룹별 상태 확인
aws elbv2 describe-target-groups \
  --load-balancer-arn $(terraform output -raw internal_alb_arn) | \
  jq '.TargetGroups[].TargetGroupName'

# Nginx Proxy 인스턴스 로그 확인 (SSM 사용)
aws ssm start-session --target i-xxxxxxxxx
# 인스턴스 접속 후:
sudo tail -f /var/log/nginx/proxy_access.log
sudo tail -f /var/log/nginx/proxy_error.log
```

### 🚨 문제 해결

#### 트래픽이 전달되지 않는 경우
```bash
# 1. FortiGate Secondary IP 설정 확인
ssh admin@<fortigate-ip>
show system interface port1

# 2. External NLB 타겟 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw external_nlb_target_group_arn)

# 3. Internal NLB (Proxy) 타겟 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw nlb_waf_tg_arn)

# 4. 보안 그룹 확인
aws ec2 describe-security-groups --group-ids <sg-id>
```

#### 도메인 라우팅이 동작하지 않는 경우
```bash
# 1. Internal ALB Listener Rules 확인
aws elbv2 describe-rules \
  --listener-arn $(terraform output -raw internal_alb_http_listener_arn)

# 2. Host Header 테스트
curl -v -H "Host: api.country-mouse.net" http://<nlb-dns>/

# 3. Nginx Proxy 설정 확인 (SSM 접속)
aws ssm start-session --target <proxy-instance-id>
sudo nginx -t
sudo cat /etc/nginx/sites-available/proxy
```

#### Nginx Proxy 헬스체크 실패
```bash
# 1. Nginx 상태 확인
aws ssm start-session --target <proxy-instance-id>
sudo systemctl status nginx

# 2. 헬스체크 엔드포인트 테스트
curl http://<proxy-private-ip>/health

# 3. Nginx 재시작
sudo systemctl restart nginx
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
🔥 FortiGate EC2 (m5.xlarge):      ~$140/월
⚖️ External NLB:                   ~$20/월
⚖️ Internal ALB:                   ~$20/월
⚖️ Internal NLB (Proxy):           ~$20/월
🔄 Nginx Proxy EC2 (t3.micro×2):   ~$15/월
💻 Backend EC2 (VPC1×2, VPC2):     ~$50/월
🌉 Transit Gateway:                ~$40/월
🔗 VPC Endpoint (SSM):             ~$7/월
📊 Data Transfer:                  변동적

총 예상 비용: ~$315-390/월 (트래픽에 따라)
```

### 비용 절약 방법
- 🏷️ **Reserved Instance**: FortiGate EC2 1년 예약 시 30% 절약
- 📦 **Spot Instance**: 개발환경 Nginx Proxy는 Spot Instance 활용
- 🕒 **스케줄링**: 개발환경 자동 중지/시작
- 🔄 **Nginx → WAF 전환**: 향후 실제 WAF 필요 시 인스턴스만 교체

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
- [ ] FortiGate 인스턴스 접근 가능
- [ ] Secondary IP (10.0.101.101) 설정 완료
- [ ] FortiGate 방화벽 정책 적용 완료
- [ ] External NLB Health Check 통과 (FortiGate)
- [ ] Internal ALB 생성 완료
- [ ] 도메인별 Target Group 생성 (api/web/app/admin)
- [ ] Host Header 라우팅 Rule 설정 완료
- [ ] Internal NLB (Proxy) 생성 완료
- [ ] Nginx Proxy 인스턴스 자동 생성 및 구성 완료
- [ ] Nginx Proxy Health Check 통과 (/health)
- [ ] 도메인별 라우팅 테스트 완료
  - [ ] api.country-mouse.net
  - [ ] web.country-mouse.net
  - [ ] app.country-mouse.net
  - [ ] admin.country-mouse.net
- [ ] Transit Gateway VPC 연결 확인
- [ ] VPC Endpoint (SSM) 동작 확인
- [ ] 모니터링 대시보드 설정
- [ ] 알람 설정 완료

### 운영 준비 체크리스트
- [ ] DNS 레코드 설정 (Route53 또는 외부 DNS)
- [ ] SSL 인증서 적용 (ACM)
- [ ] 백업 정책 수립
- [ ] 재해복구 계획 수립
- [ ] 운영 매뉴얼 작성
- [ ] Nginx Proxy → WAF 교체 계획 (선택)
- [ ] 팀 교육 완료
- [ ] 연락처 정보 업데이트

---
