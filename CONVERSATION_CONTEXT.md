# Conversation Context Summary

## Current Session State
- Date: 2025-08-19
- Working Directory: /home/eyjo/claude-code/Parnas-Vserver-Infra-Fortigate
- Git Repository: Yes (on main branch)

## Git Status at Session Start
**Modified files:**
- .terraform.lock.hcl
- README.md
- output.tf
- vpc1-extenral-nlb-internal-nlb.tf
- vpc_endpoint.tf

**Deleted files:**
- api-gateway.tf
- index.js
- vpc1-extenral-nlb-internal-alb.tf

**Untracked files:**
- FORTIGATE-CONFIGURATION.md
- vpc1-lambda-router.tf
- vpc1-lambda-router.tf.backup
- vpc1-rest-api-gateway-private.tf
- vpc1-rest-api-gateway-private.tf.backup

## Project Context
This appears to be a Terraform infrastructure project focused on:
- Fortigate security appliance configuration
- VPC networking setup
- Load balancers (NLB/ALB)
- API Gateway configurations
- Lambda routing functionality

## Recent Changes
- Transition from ALB to NLB configuration
- API Gateway modifications (REST API Gateway Private)
- Lambda router implementation
- VPC endpoint configurations

## Key Files to Monitor
- vpc1-extenral-nlb-internal-nlb.tf (main load balancer config - USER CREATED)
- FORTIGATE-CONFIGURATION.md (security configuration)

## Files Status
- **User Created:** vpc1-extenral-nlb-internal-nlb.tf
- **Exclude from implementation:** vpc1-rest-api-gateway-private.tf, vpc1-lambda-router.tf

## Architecture Design Discussion
**Secondary IP 기반 도메인 분리 구조:**

```
External NLB → Fortigate(Secondary IP: 10.0.101.101) → Internal NLB
```

**핵심 구성 요소:**
1. **Fortigate Secondary IP:**
   - Single IP: 10.0.101.101
   - Ports: 80, 443 only
   - All domain traffic: Same IP reception

2. **Internal NLB:**
   - Single Target Group: API Gateway cluster
   - Load balancing: Distribution across 3 API Gateways

3. **API Gateway 분기:**
   - Host header: Each API Gateway processes own domain only
   - Custom Domain: Domain-specific mapping

**Traffic Flow:**
1. api.example.com request → Fortigate Secondary IP
2. Internal NLB load balances to API Gateways
3. Each API Gateway checks Host header for appropriate processing

## Implementation Changes
- **API Gateway Resources:** REMOVED due to domain separation complexity
- **Backend Solution:** Nginx on EC2 instances for domain-based routing
  - 2x t3.micro instances for HA
  - Self-signed SSL certificates
  - Domain-based virtual hosts (*.example.com, *.example2.com)
- **Current State:** External NLB → Fortigate → Internal NLB → Nginx Backend

## Deployment Status
- **Terraform Plan:** ✅ Successful (15 resources to add)
- **Ready for:** `terraform apply` to create actual infrastructure

## Next Steps Required
1. **Deploy Infrastructure:** Run `terraform apply` to create resources
2. **Get VPC Endpoint ENI IPs:** Check actual ENI IPs after VPC Endpoint creation
   ```bash
   terraform output api_gateway_vpc_endpoint_ips
   aws ec2 describe-network-interfaces --network-interface-ids <ENI_ID>
   ```
3. **Add Target Group Attachments:** Uncomment and update with real ENI IPs
4. **Test Connectivity:** Verify traffic flow through the complete chain
5. **Configure Fortigate:** Set up Secondary IP and routing rules

## Complete Architecture Summary
**현재 구현된 Secondary IP 기반 도메인 분리 구조:**

1. **External NLB (인터넷 대상)**
   - Public 서브넷에 위치
   - 80/443 포트 리스너
   - Fortigate Secondary IP (10.0.101.101)로 트래픽 전달

2. **Fortigate 중간 계층**
   - Secondary IP: 10.0.101.101 (단일 IP로 모든 도메인 처리)
   - 포트: 80, 443만 사용
   - 모든 도메인 트래픽을 동일한 IP로 수신

3. **Internal NLB (백엔드 연결)**
   - Private 서브넷에 위치
   - IP 타겟 타입으로 구성
   - 3개 API Gateway에 로드밸런싱 수행

4. **API Gateway 클러스터 (도메인 유연 구성)**
   - API Gateway 1 → 10.0.102.10 (어떤 도메인이든 가능)
   - API Gateway 2 → 10.0.102.20 (어떤 도메인이든 가능)
   - API Gateway 3 → 10.0.102.30 (어떤 도메인이든 가능)
   - Host 헤더 기반으로 각자 담당 도메인 처리

**트래픽 플로우:**
```
Internet → External NLB → Fortigate(10.0.101.101) → Internal NLB → API Gateway Cluster
```

**핵심 장점:**
- 단일 Secondary IP로 모든 도메인 관리
- Fortigate 레벨에서 보안 정책 통합 적용
- Internal NLB로 API Gateway 간 로드밸런싱
- 각 API Gateway는 Host 헤더로 도메인 분기 처리

## Notes
- User requested Korean language support for context preservation
- Infrastructure appears to be in active development/modification phase
- Multiple backup files suggest iterative configuration changes
- Architecture discussion: Secondary IP based domain separation structure