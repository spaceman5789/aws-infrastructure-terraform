output "vpc_id" {
    value = module.vpc.vpc_id
}

output "alb_dns_name" {
    value       = module.ec2.alb_dns_name
    description = "по этому URL будет доступно приложение"
}

output "db_endpoint" {
    value = module.rds.db_endpoint
}
