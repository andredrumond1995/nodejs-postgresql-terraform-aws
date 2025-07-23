output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.lb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS Postgres instance"
  value       = module.db.db_instance_address
} 