output "alb_arn" {
  description = "作成されたALBのARN"
  value       = "${aws_lb.this.arn}"
}

output "alb_dns_name" {
  description = "作成されたALBのDNS"
  value       = "${aws_lb.this.dns_name}"
}

output "alb_zone_id" {
  description = "作成されたALBのZoneId"
  value       = "${aws_lb.this.zone_id}"
}

output "http_listener_arn" {
  description = "作成されたHTTP用ALB ListenerのARN"
  value       = "${aws_lb_listener.http_listener.arn}"
}

output "https_listener_arn" {
  description = "作成されたHTTPS用ALB ListenerのARN"
  value       = "${element(concat(aws_lb_listener.https_listener.*.arn, list("")), 0)}"
}
