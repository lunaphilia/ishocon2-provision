output "vpc_id" {
  description = "VPCのID"
  value       = "${aws_vpc.this.id}"
}

output "vpc_cidr_block" {
  description = "VPCのCIDR"
  value       = "${aws_vpc.this.cidr_block}"
}

output "public_subnets" {
  description = "パブリックサブネットのID一覧"
  value       = ["${aws_subnet.public.*.id}"]
}

output "private_subnets" {
  description = "プライベートサブネットのID一覧"
  value       = ["${aws_subnet.private.*.id}"]
}

output "nat_public_ips" {
  description = "NAT GatewayのPublic IPの一覧"
  value       = ["${aws_eip.nat.*.public_ip}"]
}
