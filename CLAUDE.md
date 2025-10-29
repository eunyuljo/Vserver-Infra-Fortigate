# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS-based multi-VPC security infrastructure with FortiGate firewall and Transit Gateway. The architecture provides centralized security control through FortiGate, with traffic flowing: Internet → External NLB → FortiGate (Secondary IP) → Internal ALB → Backend Services.

**Region**: ap-northeast-2 (Seoul)
**Terraform Version**: 1.11.4+ (AWS Provider v6.10.0)

### Current Infrastructure State
This is a **live production environment**. The infrastructure is currently deployed with:
- 2 VPCs (VPC1: 10.0.0.0/16, VPC2: 10.1.0.0/16)
- FortiGate EC2 instance (m5.xlarge) with 3 ENIs
- External NLB, Internal ALB, and Internal NLB (WAF proxy layer)
- Transit Gateway connecting both VPCs
- Multiple backend EC2 instances across availability zones

## Architecture

### Traffic Flow
1. External NLB receives internet traffic on ports 80/443
2. FortiGate processes traffic using **Secondary IP (10.0.101.101)** - this is critical
3. Internal ALB distributes to backend services
4. Transit Gateway enables inter-VPC communication

### Network Layout

**VPC1 (10.0.0.0/16)** - eyjo-parnas-sec-vpc1
- Public Subnets: 10.0.101.0/24, 10.0.102.0/24 (AZs 2a, 2c) - External NLB, FortiGate
- Private Subnets: 10.0.1.0/24, 10.0.2.0/24 (AZs 2a, 2c) - Internal ALB, Backend Services
- Intra Subnets: 10.0.10.0/24, 10.0.11.0/24 (Management)

**VPC2 (10.1.0.0/16)** - eyjo-parnas-sec-vpc2
- Public/Private/Intra subnets across 3 AZs (2a, 2b, 2c)
- Connected via Transit Gateway

### FortiGate Configuration

**Instance**: m5.xlarge with 3 ENIs
- **ENI0 (port1)**: 10.0.101.100 (Primary), **10.0.101.101 (Secondary)** - External interface
- **ENI1 (port2)**: 10.0.1.100 - Internal interface
- **ENI2 (port3)**: 10.0.10.100 - Management interface

**Critical**: The Secondary IP (10.0.101.101) on port1 is where all traffic from External NLB is received. This must be configured in FortiGate via:
```
config system interface
    edit "port1"
        set secondary-IP enable
        config secondaryip
            edit 1
                set ip 10.0.101.101 255.255.255.0
```

## Terraform Commands

### Initial Setup
```bash
terraform init
```

### Planning and Deployment
```bash
# Review changes before applying
terraform plan

# Apply infrastructure changes
terraform apply

# Apply with auto-approve (use with caution)
terraform apply -auto-approve

# Target specific resources
terraform apply -target=aws_instance.fortifate-ec2
terraform apply -target=module.vpc1

# Destroy infrastructure (use with caution)
terraform destroy
```

### Viewing Outputs
```bash
# View all outputs
terraform output

# View specific outputs (commonly used)
terraform output external_nlb_dns          # External NLB endpoint
terraform output internal_alb_dns          # Internal ALB endpoint
terraform output nlb_waf_dns               # Internal NLB (proxy) endpoint
terraform output instance_public_ip        # FortiGate public IP for SSH
terraform output instance_instance_id      # FortiGate instance ID (initial password)
terraform output vpc1_id                   # VPC1 ID
terraform output vpc2_id                   # VPC2 ID

# Get raw output value (useful for scripting)
terraform output -raw external_nlb_dns
```

### State Management
```bash
# View current state
terraform show

# List all resources in state
terraform state list

# Show specific resource state
terraform state show aws_instance.fortifate-ec2

# Backup state before major changes
cp terraform.tfstate terraform.tfstate.backup

# IMPORTANT: State files are tracked in git (not recommended for production)
# For production, migrate to remote backend:
# terraform {
#   backend "s3" {
#     bucket = "my-terraform-state"
#     key    = "fortigate/terraform.tfstate"
#     region = "ap-northeast-2"
#   }
# }
```

### Validation and Formatting
```bash
# Validate configuration
terraform validate

# Format all .tf files
terraform fmt -recursive

# Check what fmt would change
terraform fmt -check -recursive
```

## File Organization

Infrastructure is split by component for clarity:

**Core Network**
- `vpc.tf` - VPC definitions using terraform-aws-modules/vpc/aws (~> 5.0)
  - VPC1: 10.0.0.0/16 with public, private, and intra subnets
  - VPC2: 10.1.0.0/16 with public, private, and intra subnets
  - DNS hostnames and support enabled
  - NAT Gateways disabled (traffic routes through FortiGate)
- `trasitgateway.tf` - Transit Gateway with custom route tables (default tables disabled)
  - Default route (0.0.0.0/0) points to VPC1 for centralized egress
  - VPC1 uses intra subnets for TGW attachment (indices 0-1)
  - VPC2 uses intra subnets for TGW attachment (all AZs)

**FortiGate**
- `vpc1-fortigate-ec2.tf` - FortiGate EC2 instance, ENIs with Secondary IP configuration, security groups
  - Instance: m5.xlarge with AMI ami-007cad54955b2bc38
  - ENI0 (port1): 10.0.101.100 (Primary), **10.0.101.101 (Secondary)** - External
  - ENI1 (port2): 10.0.1.100 - Internal
  - ENI2 (port3): 10.0.10.100 - Management
  - Security groups: fortigate_sg (permissive for testing), fortigate_eni_sg (restricted)
  - Routes added for VPC2 traffic to TGW (lines 209-222)

**Load Balancers**
- `vpc1-extenral-nlb-internal-nlb.tf` - External NLB targeting FortiGate Secondary IP (10.0.101.101)
  - HTTP listener on port 80
  - HTTPS listener on port 443
  - Target: FortiGate Secondary IP 10.0.101.101
  - Health check on port 8080 (FortiGate management port)
  - Note: Internal NLB configuration is commented out (lines 94-186)
- `vpc1-internal-alb.tf` - Internal ALB for backend distribution
  - Host-based routing for *.country-mouse.net domains
  - HTTP and HTTPS listeners with ACM certificate
  - Multiple target groups for different services (api, web, app, admin)
- `vpc1-internal-nlb-waf.tf` - Internal NLB with Nginx proxy instances (if present)

**Backend Services**
- `vpc1-ec2.tf` - VPC1 EC2 instance #1
- `vpc1-ec2-2.tf` - VPC1 EC2 instance #2
- `vpc2-ec2.tf` - VPC2 EC2 instance

**Security & Access**
- `vpc1-private-waf.tf` - WAF configuration (may be commented out or placeholder)
- `vpc_endpoint.tf` - VPC endpoints for private connectivity (SSM, EC2 messages)
- `ssm-iam.tf` - IAM roles for Systems Manager access

**Configuration**
- `variables.tf` - Variable definitions (region: ap-northeast-2)
- `output.tf` - Output definitions (VPC IDs, subnet IDs, load balancer DNS names, FortiGate info)
- `FORTIGATE-CONFIGURATION.md` - Detailed FortiGate CLI configuration guide

## Key Implementation Details

### FortiGate Secondary IP Pattern
External NLB targets **10.0.101.101** (not the primary 10.0.101.100). This Secondary IP must be:
1. Defined in Terraform ENI configuration: `private_ips = ["10.0.101.100", "10.0.101.101"]` (vpc1-fortigate-ec2.tf:30)
2. Configured in FortiGate OS as secondaryip on port1 (see FORTIGATE-CONFIGURATION.md)
3. Used in NLB target group attachments: `target_id = "10.0.101.101"` (vpc1-extenral-nlb-internal-nlb.tf:50, 88)

**Why Secondary IP?**: This allows the primary IP to be used for management/other purposes while the secondary IP is dedicated to VIP (Virtual IP) traffic. FortiGate performs NAT using this secondary IP.

### Internal NLB DNS Resolution
Internal NLB uses DNS-based load balancing with dynamic IPs. When configuring FortiGate VIP:
```bash
# Determine actual NLB IPs after deployment
nslookup $(terraform output -raw internal_alb_dns)
# Use first IP in FortiGate VIP mappedip configuration
```

### Transit Gateway Design
- Default route tables **disabled** (`default_route_table_association = "disable"`, trasitgateway.tf:5-6)
- Custom route table with explicit associations (lines 14-20)
- VPC1 uses **intra subnets** for TGW attachment (indices 0-1, line 24-25)
- VPC2 uses intra subnets for TGW attachment (all AZs, line 35)
- Default route (0.0.0.0/0) points to VPC1 for centralized egress through FortiGate (lines 67-71)
- Route propagation enabled for both VPCs (lines 56-64)
- VPC1 routes added in vpc1-fortigate-ec2.tf (lines 209-222) to send VPC2 traffic to TGW

**Why Custom Route Tables?**: Prevents automatic route propagation that could bypass FortiGate inspection. All inter-VPC traffic must explicitly route through VPC1's FortiGate.

### Multi-ENI Pattern for FortiGate
FortiGate requires 3 separate network interfaces for security zones:
- **ENI0 (port1)**: External/untrusted zone - internet-facing traffic
- **ENI1 (port2)**: Internal/trusted zone - backend services
- **ENI2 (port3)**: Management zone - administrative access

Each ENI has `source_dest_check = false` to allow FortiGate to forward packets where it's not the source or destination. The primary ENI must be attached via `primary_network_interface` block, while additional ENIs use `aws_network_interface_attachment` resources.

### Security Group Patterns
- **FortiGate SG** (fortigate_sg): Permissive for testing
  - Ports: 22, 80, 443, 541, 3000, 8080, 6081, ICMP from 0.0.0.0/0
  - Port 8080 is critical for NLB health checks
  - Production should restrict SSH (port 22) to specific IPs

- **FortiGate ENI SG** (fortigate_eni_sg): Restricted to traffic ports
  - Ports: 80, 443, ICMP only
  - Applied to ENI1 and ENI2

- **Internal ALB SG** (alb_internal_sg): VPC-only access
  - Ports: 80, 443 from VPC CIDR block only
  - Prevents direct internet access to internal ALB

### Load Balancer Layering
Traffic passes through 3 load balancer layers:
1. **External NLB** (Layer 4): Internet entry point, preserves source IP
2. **FortiGate**: Security inspection and policy enforcement
3. **Internal ALB** (Layer 7): Host-based routing to backend services

Some traffic routes through an additional layer:
4. **Internal NLB** (Layer 4): For specific domains (app/admin) that need Nginx proxy layer

This layered approach separates concerns: NLB for TCP load balancing, FortiGate for security, ALB for application routing.

## Common Operations

### After Initial Deployment
1. Get FortiGate access info:
   ```bash
   terraform output instance_public_ip
   terraform output instance_instance_id  # For initial password
   ```

2. Configure FortiGate following FORTIGATE-CONFIGURATION.md:
   - Set Secondary IP on port1 (10.0.101.101)
   - Create VIP mappings
   - Configure firewall policies (ports 80, 443 only)
   - Set up routing

3. Verify load balancer health:
   ```bash
   # External NLB (FortiGate targets)
   aws elbv2 describe-target-health \
     --target-group-arn $(aws elbv2 describe-target-groups \
     --names nlb-external-tg --query 'TargetGroups[0].TargetGroupArn' \
     --output text)

   # Internal ALB target groups
   aws elbv2 describe-target-groups \
     --load-balancer-arn $(aws elbv2 describe-load-balancers \
     --names alb-internal --query 'LoadBalancers[0].LoadBalancerArn' \
     --output text)

   # Internal NLB (Nginx proxy)
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw nlb_waf_tg_arn)
   ```

### Modifying FortiGate ENIs
FortiGate uses multiple ENIs with `source_dest_check = false`. The lifecycle block ignores source_dest_check changes to prevent conflicts:
```hcl
lifecycle {
  ignore_changes = [source_dest_check]
}
```

When modifying FortiGate ENI configuration:
- Primary ENI (eni_0) is attached via `primary_network_interface` block (vpc1-fortigate-ec2.tf:6-8)
- Additional ENIs (eni_1, eni_2) are attached via `aws_network_interface_attachment` (lines 191-202)
- Changes to ENI security groups or IPs require instance stop/start

### Targeting Specific Resources
```bash
# Plan changes for specific resource
terraform plan -target=aws_instance.fortifate-ec2

# Apply changes to specific module
terraform apply -target=module.vpc1

# Target multiple resources
terraform apply -target=aws_instance.fortifate-ec2 -target=aws_network_interface.eni_0
```

### Working with AWS CLI
```bash
# Get FortiGate instance details
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_instance_id)

# Get all network interfaces attached to FortiGate
aws ec2 describe-network-interfaces \
  --filters "Name=attachment.instance-id,Values=$(terraform output -raw instance_instance_id)"

# Get Transit Gateway route tables
aws ec2 describe-transit-gateway-route-tables \
  --filters "Name=transit-gateway-id,Values=$(aws ec2 describe-transit-gateways \
  --filters 'Name=tag:Name,Values=Test-TGW' --query 'TransitGateways[0].TransitGatewayId' \
  --output text)"

# Search Transit Gateway routes
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id <route-table-id> \
  --filters "Name=state,Values=active"
```

## Monitoring and Troubleshooting

### Health Check Debugging
External NLB health checks FortiGate on port 8080 (management port). If targets are unhealthy:
1. Verify FortiGate is running and responding on 8080
2. Check security group allows traffic from NLB subnets
3. Verify Secondary IP is configured in FortiGate OS

### Traffic Flow Debugging
Use FortiGate CLI diagnostics:
```bash
ssh admin@<fortigate-public-ip>
diagnose sniffer packet any 'host 10.0.101.101' 4
get system session list
get router info routing-table all
```

### State File Issues
State files (terraform.tfstate, terraform.tfstate.backup) are tracked in repo. For production:
- Use remote backend (S3 + DynamoDB)
- Enable state locking
- Never manually edit state files

### Common Issues and Solutions

**Issue: "Error attaching network interface"**
- Cause: Trying to attach ENI while instance is running
- Solution: Stop instance, attach ENI, then start instance
```bash
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_instance_id)
aws ec2 wait instance-stopped --instance-ids $(terraform output -raw instance_instance_id)
terraform apply
```

**Issue: "TargetGroup shows unhealthy targets"**
- Cause: FortiGate Secondary IP not configured or health check port incorrect
- Solution:
  1. Verify Secondary IP in FortiGate: `show system interface port1`
  2. Check health check port matches (8080 for External NLB)
  3. Verify security group allows traffic from NLB subnets

**Issue: "Transit Gateway route propagation not working"**
- Cause: Default route tables enabled or associations missing
- Solution: Verify custom route table associations:
```bash
aws ec2 describe-transit-gateway-route-tables \
  --filters "Name=tag:Name,Values=TGW-Custom-Route-Table"
```

**Issue: "Changes to FortiGate ENI not applying"**
- Cause: Lifecycle block ignoring source_dest_check
- Solution: This is intentional. For other ENI changes, use targeted apply:
```bash
terraform apply -target=aws_network_interface.eni_0
```

## Important Notes

### Critical Configuration Details
- **FortiGate Secondary IP**: The most critical configuration is the Secondary IP (10.0.101.101) on ENI0/port1. External NLB targets this IP exclusively. Must be configured both in Terraform (`private_ips = ["10.0.101.100", "10.0.101.101"]`) and in FortiGate OS via CLI.

- **No NAT Gateways**: Traffic routes through FortiGate instead of NAT Gateway for centralized security control. Both VPCs have NAT Gateway configuration commented out in vpc.tf.

- **Transit Gateway Routing**: Default route (0.0.0.0/0) points to VPC1 attachment, forcing all VPC2 egress traffic through FortiGate for inspection.

### Environment-Specific Values
- **AMI Hardcoded**: FortiGate AMI `ami-007cad54955b2bc38` is specific to ap-northeast-2. After initial setup, use snapshots to preserve configuration. AMI may need updating for other regions.

- **SSL Certificate**: Internal ALB HTTPS listener references ACM certificate ARN `arn:aws:acm:ap-northeast-2:626635430480:certificate/95498647-17d3-4dcb-b69c-aad715823372`. Update this for your own domain certificates.

- **SSH Key**: Uses `eyjo-fnf-test-key` for EC2 access. Ensure this key pair exists in ap-northeast-2 before deployment.

- **Domain**: Architecture uses `*.country-mouse.net` for host-based routing. Update ALB listener rules for your own domains.

### State Management Warning
- **State Files in Git**: terraform.tfstate and terraform.tfstate.backup are currently tracked in git (not recommended for production). Consider migrating to S3 backend with DynamoDB locking for production use.
