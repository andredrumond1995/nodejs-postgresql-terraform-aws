output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.lb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS Postgres instance"
  value       = module.db.db_instance_address
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for HTTPS access to the API"
  value       = aws_cloudfront_distribution.alb.domain_name
} 