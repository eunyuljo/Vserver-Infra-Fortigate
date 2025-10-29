# Parnas Vserver Infrastructure with FortiGate

## 개요

AWS에서 FortiGate 방화벽 중심으로 구축한 멀티 VPC 보안 인프라입니다.
처음엔 단순하게 시작했는데 요구사항이 추가되면서 도메인별 라우팅이랑 프록시 레이어까지 붙게 됐네요.

### 주요 특징
- FortiGate로 모든 인바운드 트래픽 필터링
- Transit Gateway로 VPC 간 통신 및 중앙 집중식 egress
- ALB에서 도메인별(*.country-mouse.net) 라우팅 처리
- 일단 Nginx 프록시로 구성했고 나중에 WAF 필요하면 교체 예정
- 로드밸런서 여러 개 거치는데 각각 용도가 달라서 어쩔 수 없음

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

### 트래픽 흐름

외부에서 들어오는 요청이 실제 백엔드까지 도달하는 과정:

1. 인터넷 → External NLB (80/443 포트 리스닝)
2. NLB → FortiGate의 Secondary IP (10.0.101.101)
   - Secondary IP 설정이 핵심. 이거 빠뜨리면 트래픽 안들어옴
3. FortiGate 방화벽 통과 → Internal ALB로 전달
4. Internal ALB에서 Host Header 보고 라우팅
   - api/web는 바로 EC2로
   - app/admin은 Nginx 프록시 거쳐서
5. Nginx Proxy (필요한 경우만) → 백엔드 EC2
6. VPC2는 Transit Gateway 통해서 VPC1 거쳐 나감 (중앙 집중식)

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

### 주요 컴포넌트

#### FortiGate 방화벽
- m5.xlarge (4 vCPU, 16GB RAM)
- ENI 3개 붙어있음:
  - port1 (External): 10.0.101.100이 Primary, **10.0.101.101이 Secondary** - 여기가 중요
  - port2 (Internal): 10.0.1.100
  - port3 (Management): 10.0.10.100
- 모든 인바운드 트래픽이 여기 거쳐감
- 보안그룹은 일단 22/80/443/ICMP 다 열어놨음 (나중에 조이는게 좋긴 함)

#### 로드밸런서들

**External NLB** (Public)
- 인터넷 진입점
- 80/443 리스닝해서 FortiGate Secondary IP로 보냄
- 2개 AZ에 분산

**Internal ALB** (Private)
- 도메인 라우팅 담당
- Host Header 보고 아래처럼 분기:
  - api.country-mouse.net → API 타겟
  - web.country-mouse.net → Web 타겟
  - app.country-mouse.net → App 타겟 (→ NLB)
  - admin.country-mouse.net → Admin 타겟 (→ NLB)
- SSL 인증서는 ACM에서 가져옴

**Internal NLB** (Private)
- app/admin 도메인용 프록시 앞단
- TCP 80 포트만
- Cross-AZ 로드밸런싱 꺼놨음 (비용 절감)

#### Nginx Proxy
- Ubuntu 24.04, t3.micro 2대 (AZ별 하나씩)
- 지금은 그냥 프록시 역할만 함
- 나중에 실제 WAF 필요하면 이거 교체하면 됨
- User Data로 자동 설치되게 해놨음
- /health 엔드포인트로 헬스체크 받음

#### Transit Gateway
- VPC1, VPC2 연결용
- Default route table 안쓰고 커스텀으로 만듦
- VPC2에서 나가는 트래픽은 전부 VPC1 FortiGate 거쳐서 나감
- 이래야 중앙에서 로그 보고 통제할 수 있어서

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

## 배포 방법

### 필요한거
- Terraform 1.0 이상
- AWS CLI 2.0 이상
- jq 있으면 편함
- AWS 계정에 EC2, VPC, ELB, IAM 권한

### 배포 절차

**1. 환경 준비**
```bash
# 리포지토리 클론
git clone <repository-url>
cd Parnas-Vserver-Infra-Fortigate

# AWS 계정 확인
aws sts get-caller-identity
```

**2. Terraform 실행**
```bash
terraform init
terraform plan  # 뭐가 생성될지 미리 확인
terraform apply
```

**3. FortiGate 설정**
```bash
# 접속 정보 확인
terraform output instance_public_ip
terraform output instance_instance_id

# FortiGate 설정은 FORTIGATE-CONFIGURATION.md 보고 진행
```

**4. 도메인 라우팅 확인**
```bash
# ALB 정보 확인
INTERNAL_ALB_DNS=$(terraform output -raw internal_alb_dns)
echo "Internal ALB: $INTERNAL_ALB_DNS"

# NLB 정보 확인
NLB_WAF_DNS=$(terraform output -raw nlb_waf_dns)
echo "Internal NLB (Proxy): $NLB_WAF_DNS"

# Nginx Proxy는 자동으로 생성되고 User Data로 설치됨
```

**5. DNS 설정**
```bash
# Route53이나 DNS 서버에서 아래처럼 CNAME 추가:
# api.country-mouse.net    → External NLB DNS
# web.country-mouse.net    → External NLB DNS
# app.country-mouse.net    → External NLB DNS
# admin.country-mouse.net  → External NLB DNS
```

**6. 테스트**
```bash
EXTERNAL_NLB_DNS=$(terraform output -raw external_nlb_dns)

# Host Header 테스트 (FortiGate 설정 후)
curl -H "Host: api.country-mouse.net" http://$EXTERNAL_NLB_DNS/
curl -H "Host: web.country-mouse.net" http://$EXTERNAL_NLB_DNS/
curl -H "Host: app.country-mouse.net" http://$EXTERNAL_NLB_DNS/
curl -H "Host: admin.country-mouse.net" http://$EXTERNAL_NLB_DNS/

# DNS 설정 후에는 그냥
curl http://api.country-mouse.net/
curl http://web.country-mouse.net/
```

## 운영

### 주요 정보 보는법
```bash
# 배포 후 확인할거
terraform output external_nlb_dns          # External NLB DNS
terraform output internal_alb_dns          # Internal ALB DNS
terraform output nlb_waf_dns               # Internal NLB (Proxy) DNS
terraform output instance_public_ip        # FortiGate Public IP
terraform output instance_instance_id      # FortiGate Instance ID
```

### 모니터링
```bash
# External NLB 상태 (FortiGate)
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw external_nlb_target_group_arn)

# Internal NLB 상태 (Nginx Proxy)
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw nlb_waf_tg_arn)

# Internal ALB 타겟 그룹들
aws elbv2 describe-target-groups \
  --load-balancer-arn $(terraform output -raw internal_alb_arn) | \
  jq '.TargetGroups[].TargetGroupName'

# Nginx Proxy 로그 (SSM으로 접속)
aws ssm start-session --target i-xxxxxxxxx
# 접속 후:
sudo tail -f /var/log/nginx/proxy_access.log
sudo tail -f /var/log/nginx/proxy_error.log
```

### 트러블슈팅

**트래픽이 안들어올 때**
```bash
# 1. FortiGate Secondary IP 확인 (제일 중요)
ssh admin@<fortigate-ip>
show system interface port1

# 2. NLB 타겟 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw external_nlb_target_group_arn)

# 3. Proxy NLB 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw nlb_waf_tg_arn)

# 4. 보안그룹
aws ec2 describe-security-groups --group-ids <sg-id>
```

**도메인 라우팅 안될 때**
```bash
# ALB Listener Rules 확인
aws elbv2 describe-rules \
  --listener-arn $(terraform output -raw internal_alb_http_listener_arn)

# Host Header 테스트
curl -v -H "Host: api.country-mouse.net" http://<nlb-dns>/

# Nginx Proxy 설정 확인 (SSM 접속)
aws ssm start-session --target <proxy-instance-id>
sudo nginx -t
sudo cat /etc/nginx/sites-available/proxy
```

**Nginx Proxy 헬스체크 실패**
```bash
# Nginx 상태
aws ssm start-session --target <proxy-instance-id>
sudo systemctl status nginx

# 헬스체크 엔드포인트
curl http://<proxy-private-ip>/health

# 재시작
sudo systemctl restart nginx
```

## 보안

### FortiGate 정책
- 80, 443 포트만 허용
- DDoS 보호 켜놨음
- IPS 활성화
- 로그는 다 수집

### 보안 그룹
```bash
# FortiGate SG
Inbound:
  - 22/tcp from 0.0.0.0/0        # SSH (나중에 IP 제한하는게 좋음)
  - 80/tcp from 0.0.0.0/0        # HTTP
  - 443/tcp from 0.0.0.0/0       # HTTPS
  - 541/tcp from 0.0.0.0/0       # FortiGate 관리 포트
  - ICMP from 0.0.0.0/0          # Ping

# Internal ALB SG
Inbound:
  - 80/443 from VPC CIDR only
```

## 모니터링

### CloudWatch 메트릭
```bash
# 보통 이런거 보면 됨
- AWS/ApplicationELB: TargetResponseTime, HTTPCode_Target_2XX_Count
- AWS/EC2: CPUUtilization, NetworkIn, NetworkOut (FortiGate)
```

### 알람 예시
```bash
# 에러율 알람
aws cloudwatch put-metric-alarm \
  --alarm-name "High-Error-Rate" \
  --metric-name 4XXError \
  --namespace AWS/ApiGateway \
  --statistic Sum \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

## 비용

### 월간 예상 (서울 리전)
```
FortiGate EC2 (m5.xlarge):      ~$140/월
External NLB:                   ~$20/월
Internal ALB:                   ~$20/월
Internal NLB (Proxy):           ~$20/월
Nginx Proxy EC2 (t3.micro×2):   ~$15/월
Backend EC2 (VPC1×2, VPC2):     ~$50/월
Transit Gateway:                ~$40/월
VPC Endpoint (SSM):             ~$7/월
Data Transfer:                  변동적

대충 $315-390/월 정도 (트래픽에 따라 달라짐)
```

### 줄이는 방법
- FortiGate는 Reserved Instance로 30% 정도 절약 가능
- 개발환경 Nginx는 Spot Instance 써도 됨
- 개발환경은 스케줄링으로 자동 on/off
- Nginx 대신 실제 WAF 필요하면 인스턴스만 교체하면 됨

## 유지보수

### FortiGate 업그레이드
```bash
# 스냅샷 먼저
aws ec2 create-snapshot \
  --volume-id <fortigate-volume-id> \
  --description "Pre-upgrade snapshot"

# 설정 백업
ssh admin@<fortigate-ip>
execute backup config flash backup_$(date +%Y%m%d)

# 업그레이드는 웹 GUI에서
```

### Terraform 업데이트
```bash
# 상태 파일 백업 필수
cp terraform.tfstate terraform.tfstate.backup

# 버전 확인
terraform version
terraform providers

# 한번에 다 하지말고 단계적으로
terraform plan -target=module.specific
```

## 기타

### 다중 환경
```bash
# 환경별 tfvars 만들어서
terraform.tfvars.dev
terraform.tfvars.staging
terraform.tfvars.prod

# 배포할 때 지정
terraform apply -var-file=terraform.tfvars.prod
```

### 백업 자동화
```bash
# Lambda로 정기 백업 돌리면 편함
- FortiGate 설정
- Terraform state를 S3로
- CloudWatch Events로 스케줄링
```

## 참고

### 추가 문서
- [FortiGate 설정 가이드](./FORTIGATE-CONFIGURATION.md)

### 이슈 있으면
```
1. 환경 (dev/staging/prod)
2. 언제 발생했는지
3. 에러 메시지
4. 재현 방법
5. 예상했던거 vs 실제 결과
```

---

## 체크리스트

### 배포 완료 후
- [ ] Terraform apply 성공
- [ ] FortiGate 접속 됨
- [ ] Secondary IP (10.0.101.101) 설정 완료
- [ ] FortiGate 방화벽 정책 적용
- [ ] External NLB Health Check 통과
- [ ] Internal ALB 생성
- [ ] 도메인별 Target Group 생성 (api/web/app/admin)
- [ ] Host Header 라우팅 Rule 설정
- [ ] Internal NLB (Proxy) 생성
- [ ] Nginx Proxy 인스턴스 자동 생성/구성
- [ ] Nginx Proxy Health Check 통과 (/health)
- [ ] 도메인 라우팅 테스트
  - [ ] api.country-mouse.net
  - [ ] web.country-mouse.net
  - [ ] app.country-mouse.net
  - [ ] admin.country-mouse.net
- [ ] Transit Gateway 연결 확인
- [ ] VPC Endpoint (SSM) 동작 확인
- [ ] 모니터링/알람 설정

### 운영 시작 전
- [ ] DNS 레코드 설정
- [ ] SSL 인증서 적용
- [ ] 백업 정책 정리
- [ ] Nginx → WAF 교체 계획 (선택)

---
