/**
 * tf_vpc
 * ---
 * 
 * [![CircleCI](https://cci.dmm.com/gh/sre-terraform/tf-vpc.svg?style=svg)](https://cci.dmm.com/gh/sre-terraform/tf-vpc)
 * 
 * # About
 * <img src="https://git.dmm.com/raw/sre-terraform/tf-vpc/master/docs/architecture.png" />
 * 
 * TerraformによるVPCリソース管理用コード
 * 
 * # Components
 * - VPC
 * - Internet Gateway
 * - Subnet
 * - Route Table
 * - NAT Gateway
 *
 * # Usage
 * ```ruby
 * module "vpc" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf-vpc.git?ref=v1.1.0"
 *
 *   name = "myapp"
 *
 *   tags = {
 *     Terraform = "true"
 *     Environment = "dev"
 *   }
 * }
 * ```
 *
 * ## NAT Gateway
 * NAT Gatewayを使用する場合の例。  
 * `one_nat_gateway_per_az` を `true` にすることで1AZに対して1つのNAT Gatewayが作成される。  
 * デフォルトのままだとNAT Gatewayは作成されない。
 *
 * ```ruby
 * module "vpc" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf-vpc.git?ref=v1.1.0"
 *
 *   name = "myapp"
 *
 *   #XXX: NAT Gatewayを1つに節約したい場合はこちらをtrueにする
 *   # single_nat_gateway = true
 *
 *   one_nat_gateway_per_az = true
 * }
 * ```
 * 
 * `nat_ips` を与えることで、NatGatewayに付与されるElasticIPの管理をモジュール外に出すことができる  
 * 指定する場合は作られるNAT Gatewayの数だけElastic IPを指定する必要がある
 * ```ruby
 * resource "aws_eip" "nat" {
 *   count = "3"
 * 
 *   vpc = true
 * 
 *   tags = "${merge(map("Name", format("%s-%d", local.name, count.index)), local.tags)}"
 * }
 * 
 * module "vpc" {
 * ...
 * 
 *   nat_ips = "${aws_eip.nat.*.id}"
 * 
 * ...
 * }
 * ```
 * 
 * 
 * # Generate documentation
 * ```
 * $ terraform-docs markdown ./ > README.md
 * ```
 * 
 * 
 * # Reference
 * - [terraform-aws-modules/terraform-aws-vpc: Terraform module which creates VPC resources on AWS](https://github.com/terraform-aws-modules/terraform-aws-vpc)
 *
 */

#########################
# VPC
#########################
resource "aws_vpc" "this" {
  cidr_block = "${var.cidr}"

  tags = "${merge(map("Name", format("%s", var.name)), var.tags)}"

  enable_dns_support   = "${var.enable_dns}"
  enable_dns_hostnames = "${var.enable_dns}"
}

#########################
# Flow Log
#########################
resource "aws_iam_role" "flowlog" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "flowlog_policy" {
  role = "${aws_iam_role.flowlog.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "flowlog" {
  name              = "/${var.name}/vpc/flow"
  retention_in_days = "${var.flowlog_retention_in_days}"
}

resource "aws_flow_log" "flowlog" {
  depends_on = ["aws_cloudwatch_log_group.flowlog"]

  iam_role_arn    = "${aws_iam_role.flowlog.arn}"
  log_destination = "${aws_cloudwatch_log_group.flowlog.arn}"
  traffic_type    = "ALL"
  vpc_id          = "${aws_vpc.this.id}"
}

#########################
# Internet Gateway
#########################
resource "aws_internet_gateway" "this" {
  vpc_id = "${aws_vpc.this.id}"

  tags = "${merge(map("Name", format("%s", var.name)), var.tags)}"
}

#########################
# Public Route Table
#########################
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.this.id}"

  tags = "${merge(map("Name", format("%s-${var.public_subnet_suffix}", var.name)), var.tags)}"
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"
}

#########################
# Public Subnet
#########################
resource "aws_subnet" "public" {
  count = "${length(var.public_subnets)}"

  vpc_id = "${aws_vpc.this.id}"

  cidr_block        = "${element(var.public_subnets, count.index)}"
  availability_zone = "${element(var.azs, count.index)}"

  tags = "${merge(map("Name", format("%s-${var.public_subnet_suffix}-%d", var.name, count.index)), var.tags)}"
}

resource "aws_route_table_association" "public" {
  count = "${length(var.public_subnets)}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

#########################
# Private Route Table
#########################
resource "aws_route_table" "private" {
  count = "${length(var.private_subnets)}"

  vpc_id = "${aws_vpc.this.id}"

  tags = "${merge(map("Name", format("%s-${var.private_subnet_suffix}-%d", var.name, count.index)), var.tags)}"
}

#########################
# Private Subnet
#########################
resource "aws_subnet" "private" {
  count = "${length(var.private_subnets)}"

  vpc_id = "${aws_vpc.this.id}"

  cidr_block        = "${element(var.private_subnets, count.index)}"
  availability_zone = "${element(var.azs, count.index)}"

  tags = "${merge(map("Name", format("%s-${var.private_subnet_suffix}-%d", var.name, count.index)), var.tags)}"
}

resource "aws_route_table_association" "private" {
  count = "${length(var.private_subnets)}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, (var.single_nat_gateway ? 0 : count.index))}"
}

#########################
# NAT Gateway
#########################
locals {
  nat_gateway_count = "${var.single_nat_gateway ? 1 : (var.one_nat_gateway_per_az ? length(var.azs) : 0)}"
  nat_gateway_ips   = "${split(",", length(var.nat_ips) == local.nat_gateway_count ? join(",", var.nat_ips) : join(",", aws_eip.nat.*.id))}"
}

resource "aws_eip" "nat" {
  count = "${length(var.nat_ips) == local.nat_gateway_count ? 0 : local.nat_gateway_count}"

  vpc = true

  tags = "${merge(map("Name", format("%s-%d", var.name, count.index)), var.tags)}"
}

resource "aws_nat_gateway" "this" {
  count = "${local.nat_gateway_count}"

  allocation_id = "${element(local.nat_gateway_ips, (var.single_nat_gateway ? 0 : count.index))}"
  subnet_id     = "${element(aws_subnet.public.*.id, (var.single_nat_gateway ? 0 : count.index))}"

  tags = "${merge(map("Name", format("%s-%d", var.name, (var.single_nat_gateway ? 0 : count.index))), var.tags)}"

  depends_on = ["aws_eip.nat"]
}

resource "aws_route" "private_nat_gateway" {
  count = "${local.nat_gateway_count}"

  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, (var.single_nat_gateway ? 0 : count.index))}"
}
