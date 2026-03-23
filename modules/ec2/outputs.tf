output "alb_dns_name" {
    value       = aws_lb.main.dns_name
    description = "DNS name of the load balancer"
}

output "alb_arn" {
    value       = aws_lb.main.arn
    description = "ARN of the load balancer"
}