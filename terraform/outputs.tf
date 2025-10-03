output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}
output "service_url_https" {
  value = "https://${aws_lb.app_alb.dns_name}"
}
output "ecr_repository_url" {
  value = aws_ecr_repository.repo.repository_url
}
output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}
output "ecs_service_name" {
  value = aws_ecs_service.service.name
}
