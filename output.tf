## vpc1 ##
output "vpc1_id" {
  value = module.vpc1.vpc_id
}

output "vpc1_public_subnet_ids" {
  value = module.vpc1.public_subnets
}

output "vpc1_private_subnet_ids" {
  value = module.vpc1.private_subnets
}

## vpc1 ##
output "vpc2_id" {
  value = module.vpc2.vpc_id
}

output "vpc2_public_subnet_ids" {
  value = module.vpc2.public_subnets
}

output "vpc2_private_subnet_ids" {
  value = module.vpc2.private_subnets
}


output "external_nlb_dns" {
  description = "External NLB DNS name"
  value       = aws_lb.nlb_external.dns_name
}

# output "internal_nlb_dns" {
#   description = "Internal NLB DNS name" 
#   value       = aws_lb.nlb_internal.dns_name
# }

# output "internal_nlb_http_target_group_arn" {
#   description = "Internal NLB HTTP Target Group ARN (Nginx Backend)"
#   value       = aws_lb_target_group.nlb_internal_http_tg.arn
# }

# output "internal_nlb_https_target_group_arn" {
#   description = "Internal NLB HTTPS Target Group ARN (Nginx Backend)"
#   value       = aws_lb_target_group.nlb_internal_https_tg.arn
# }

output "vpc1_ec2_private_ip" {
  description = "VPC1 EC2 instance private IP"
  value = aws_instance.vpc1-ec2.private_ip
}

output "internal_alb_dns" {
  description = "Internal ALB DNS name"
  value       = aws_lb.alb_internal.dns_name
}

output "internal_alb_zone_id" {
  description = "Internal ALB Zone ID"
  value       = aws_lb.alb_internal.zone_id
}




