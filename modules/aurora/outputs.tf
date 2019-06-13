output "endpoint" {
  description = "RDS エンドポイント名"
  value       = "${aws_rds_cluster.this.endpoint}"
}

output "reader_endpoint" {
  description = "RDS 読み込み専用 エンドポイント名"
  value       = "${aws_rds_cluster.this.reader_endpoint}"
}
