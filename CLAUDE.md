# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS-based multi-VPC security infrastructure with FortiGate firewall and Transit Gateway. The architecture provides centralized security control through FortiGate, with traffic flowing: Internet → External NLB → FortiGate (Secondary IP) → Internal ALB → Backend Services.

**Region**: ap-northeast-2 (Seoul)

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

# Destroy infrastructure (use with caution)
terraform destroy
```

### Viewing Outputs
```bash
# View all outputs
terraform output

# View specific outputs
terraform output external_nlb_dns
terraform output internal_alb_dns
terraform output instance_public_ip
terraform output instance_instance_id
```

### State Management
```bash
# View current state
terraform show

# List all resources in state
terraform state list

# Backup state before major changes
cp terraform.tfstate terraform.tfstate.backup
```

## File Organization

Infrastructure is split by component for clarity:

**Core Network**
- `vpc.tf` - VPC definitions using terraform-aws-modules/vpc module
- `trasitgateway.tf` - Transit Gateway with custom route tables (default tables disabled)

**FortiGate**
- `vpc1-fortigate-ec2.tf` - FortiGate EC2 instance, ENIs with Secondary IP configuration, security groups

**Load Balancers**
- `vpc1-extenral-nlb-internal-nlb.tf` - External NLB targeting FortiGate Secondary IP (10.0.101.101)
- `vpc1-internal-alb.tf` - Internal ALB for backend distribution

**Backend Services**
- `vpc1-ec2.tf`, `vpc1-ec2-2.tf` - VPC1 EC2 instances
- `vpc2-ec2.tf` - VPC2 EC2 instances

**Security & Access**
- `vpc1-private-waf.tf` - WAF configuration
- `vpc_endpoint.tf` - VPC endpoints for private connectivity
- `ssm-iam.tf` - IAM roles for Systems Manager access

**Configuration**
- `variables.tf` - Variable definitions
- `output.tf` - Output definitions

## Key Implementation Details

### FortiGate Secondary IP Pattern
External NLB targets **10.0.101.101** (not the primary 10.0.101.100). This Secondary IP must be:
1. Defined in Terraform ENI configuration: `private_ips = ["10.0.101.100", "10.0.101.101"]`
2. Configured in FortiGate OS as secondaryip on port1
3. Used in NLB target group attachments: `target_id = "10.0.101.101"`

### Internal NLB DNS Resolution
Internal NLB uses DNS-based load balancing with dynamic IPs. When configuring FortiGate VIP:
```bash
# Determine actual NLB IPs after deployment
nslookup $(terraform output -raw internal_alb_dns)
# Use first IP in FortiGate VIP mappedip configuration
```

### Transit Gateway Design
- Default route tables **disabled** (`default_route_table_association = "disable"`)
- Custom route table with explicit associations
- VPC1 uses public subnets for TGW attachment (indices 0-1)
- VPC2 uses intra subnets for TGW attachment
- Default route (0.0.0.0/0) points to VPC1 for centralized egress through FortiGate

### Security Group Patterns
- FortiGate SG: Permissive for testing (SSH, HTTP, HTTPS, FortiGate mgmt ports, ICMP from 0.0.0.0/0)
- FortiGate ENI SG: HTTP/HTTPS/ICMP only
- Internal ALB SG: Restricted to VPC CIDR block

## Common Operations

### After Initial Deployment
1. Get FortiGate access info:
   ```bash
   terraform output instance_public_ip
   terraform output instance_instance_id  # For initial password
   ```

2. Configure FortiGate following FORTIGATE-CONFIGURATION.md:
   - Set Secondary IP on port1
   - Create VIP mappings
   - Configure firewall policies (ports 80, 443 only)
   - Set up routing

3. Verify load balancer health:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw external_nlb_target_group_arn)
   ```

### Modifying FortiGate ENIs
FortiGate uses multiple ENIs with `source_dest_check = false`. The lifecycle block ignores source_dest_check changes to prevent conflicts:
```hcl
lifecycle {
  ignore_changes = [source_dest_check]
}
```

### Targeting Specific Resources
```bash
# Plan changes for specific resource
terraform plan -target=aws_instance.fortifate-ec2

# Apply changes to specific module
terraform apply -target=module.vpc1
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

## Important Notes

- **No NAT Gateways**: Traffic routes through FortiGate instead of NAT Gateway for centralized security
- **AMI Hardcoded**: FortiGate AMI `ami-007cad54955b2bc38` is specific to ap-northeast-2. After initial setup, use snapshots
- **SSL Certificate**: Internal ALB HTTPS listener references ACM certificate ARN `arn:aws:acm:ap-northeast-2:626635430480:certificate/95498647-17d3-4dcb-b69c-aad715823372`
- **SSH Key**: Uses `eyjo-fnf-test-key` for EC2 access
