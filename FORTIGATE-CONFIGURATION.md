# Fortigate 방화벽 설정 가이드

## 아키텍처 개요

```
클라이언트 → External NLB → Fortigate(Secondary IP) → Internal NLB → API Gateway
                              (10.0.101.101)
```

## Fortigate 설정

### 1. 네트워크 인터페이스 설정

#### Interface 구성
- **port1**: 외부 인터페이스 (10.0.101.100 primary, 10.0.101.101 secondary)
- **port2**: 내부 인터페이스 (10.0.1.100)
- **port3**: 관리 인터페이스 (10.0.10.100)

#### Secondary IP 설정
```bash
config system interface
    edit "port1"
        set ip 10.0.101.100 255.255.255.0
        set secondary-IP enable
        config secondaryip
            edit 1
                set ip 10.0.101.101 255.255.255.0
                set allowaccess ping https http
            next
        end
    next
end
```

### 2. 방화벽 정책 설정

#### 기본 정책 (포트 80, 443만 허용)
```bash
config firewall policy
    edit 1
        set name "External-to-Internal-HTTP"
        set srcintf "port1"
        set dstintf "port2"
        set srcaddr "all"
        set dstaddr "all"
        set service "HTTP"
        set action accept
        set schedule "always"
        set logtraffic all
    next
    edit 2
        set name "External-to-Internal-HTTPS"
        set srcintf "port1"
        set dstintf "port2"
        set srcaddr "all"
        set dstaddr "all"
        set service "HTTPS"
        set action accept
        set schedule "always"
        set logtraffic all
    next
end
```

### 3. Virtual IP 설정

#### VIP for HTTP/HTTPS (트래픽 전달용)
```bash
config firewall vip
    edit "VIP-HTTP-80"
        set extip 10.0.101.101           # External IP (Secondary IP)
        set mappedip "10.0.1.247"        # Internal NLB 실제 IP (nslookup으로 확인)
        set extintf "port1"              # 외부 인터페이스
        set portforward enable           # 포트 포워딩 활성화
        set extport 80                   # 외부 포트
        set mappedport 80                # Internal NLB는 80포트 사용 (백엔드 서버)
    next
    edit "VIP-HTTPS-443"
        set extip 10.0.101.101           # External IP (Secondary IP)  
        set mappedip "10.0.1.247"        # Internal NLB 실제 IP (nslookup으로 확인)
        set extintf "port1"              # 외부 인터페이스
        set portforward enable           # 포트 포워딩 활성화
        set extport 443                  # 외부 포트
        set mappedport 80                # Internal NLB는 80포트 사용 (백엔드 서버)
    next
end
```

### mappedip 설명:
- **extip**: 외부에서 접근하는 IP (Secondary IP: 10.0.101.101)
- **mappedip**: 실제 트래픽이 전달될 내부 IP (Internal NLB IP)
- **extport**: 외부에서 요청하는 포트 (80, 443)
- **mappedport**: 내부로 전달할 포트 (Internal NLB는 80포트 사용 - 백엔드 서버)

### 주의사항:
1. **mappedip는 Internal NLB의 실제 Private IP**를 사용해야 합니다
2. **terraform apply 후 Internal NLB IP 확인 필요**:
   ```bash
   # 1. Internal NLB DNS 이름 확인
   terraform output internal_nlb_dns
   
   # 2. DNS를 통해 실제 IP 확인 (NLB는 다중 IP 사용)
   nslookup <internal-nlb-dns>
   
   # 또는 dig 명령어 사용
   dig +short <internal-nlb-dns>
   
   # 예시 결과: 
   # 10.0.1.247 (AZ-1a)
   # 10.0.2.72  (AZ-1c)
   ```

3. **VIP 설정시 첫 번째 IP 사용 권장**:
   ```bash
   # 첫 번째 AZ의 IP 주소를 mappedip로 사용
   set mappedip "10.0.1.247"  # 실제 확인된 IP로 변경
   ```

### 📌 중요: NLB IP는 동적으로 할당됩니다
- NLB는 고정 IP가 아닌 DNS 기반 로드밸런싱 사용
- 각 AZ마다 다른 IP 주소 할당  
- Fortigate VIP에서는 하나의 IP만 지정 (보통 첫 번째 AZ)
   ```

### 4. 라우팅 설정

#### Static Routes
```bash
config router static
    edit 1
        set gateway 10.0.101.1
        set device "port1"
        set dst 0.0.0.0 0.0.0.0
    next
    edit 2
        set gateway 10.0.1.1
        set device "port2"
        set dst 10.0.0.0 255.255.0.0
    next
end
```

## 트래픽 플로우

### HTTP 트래픽 (포트 80)
1. External NLB가 80포트 트래픽을 10.0.101.101로 전달
2. Fortigate가 secondary IP(10.0.101.101)에서 수신
3. 방화벽 정책 적용 후 Internal NLB로 전달
4. Internal NLB가 API Gateway VPC Endpoint로 라우팅
5. API Gateway가 호스트헤더 기반으로 백엔드 분기

### HTTPS 트래픽 (포트 443)
1. External NLB가 443포트 트래픽을 10.0.101.101로 전달
2. Fortigate가 secondary IP(10.0.101.101)에서 수신
3. 방화벽 정책 적용 후 Internal NLB로 전달
4. Internal NLB가 API Gateway VPC Endpoint로 라우팅
5. API Gateway가 호스트헤더 기반으로 백엔드 분기

## 호스트헤더 기반 라우팅

### 도메인별 라우팅 규칙
- **api.example.com** → Backend A
- **web.example.com** → Backend B  
- **admin.example.com** → Backend C

### API Gateway 동작
1. 모든 요청을 Internal NLB를 통해 수신
2. 원본 Host 헤더를 유지하여 백엔드로 전달
3. 백엔드 애플리케이션에서 Host 헤더 기반 처리

## 보안 고려사항

### 최소 권한 원칙
- 방화벽에서 80, 443 포트만 허용
- 다른 모든 포트는 차단
- 로그 모니터링 활성화

### 방화벽 설정 최적화
```bash
# DDoS 보호 설정
config system global
    set anti-flood-rate 10000
    set dos-protection enable
end

# IPS 설정
config ips global
    set traffic-direction both
    set scan-mode deep
end
```

## 모니터링 및 로깅

### 로그 설정
```bash
config log setting
    set fwpolicy-implicit-log enable
    set local-in-policy enable
    set local-in-deny-unicast enable
    set local-out enable
end
```

### 주요 모니터링 지표
- 트래픽 볼륨 (port1 → port2)
- 차단된 연결 수
- 응답 시간
- 에러율

## 문제 해결

### 트래픽이 전달되지 않는 경우
1. Secondary IP 설정 확인
2. 방화벽 정책 확인
3. 라우팅 테이블 확인
4. VIP 설정 확인

### 디버깅 명령어
```bash
# 트래픽 모니터링
diagnose sniffer packet any 'host 10.0.101.101' 4

# 방화벽 세션 확인
get system session list

# 라우팅 테이블 확인
get router info routing-table all
```

## 백업 및 복구

### 설정 백업
```bash
execute backup config flash backup_YYYYMMDD
```

### 주기적 백업 스케줄
- 매일 자동 백업 설정 권장
- S3 또는 외부 스토리지에 보관

## 성능 튜닝

### 권장 설정
```bash
config system global
    set per-user-bw-limit 1000
    set per-user-bw-timer 60
end

config system npu
    set capwap-offload enable
    set gtp-offload enable
end
```

이 설정을 통해 방화벽 secondary IP를 통한 단순하고 효율적인 트래픽 관리가 가능합니다.