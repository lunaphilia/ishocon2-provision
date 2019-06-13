output "service_name" {
  description = "ECS Service名"
  value       = "${aws_ecs_service.this.name}"
}

output "target_group_arn" {
  description = "ターゲットグループのARN"
  value       = "${aws_lb_target_group.this.arn}"
}

output "target_group_name" {
  description = "ターゲットグループのname"
  value       = "${aws_lb_target_group.this.name}"
}
