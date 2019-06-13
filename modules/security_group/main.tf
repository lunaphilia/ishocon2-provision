/**
 *
 * tf_security_group
 * ---
 *
 * [![CircleCI](https://cci.dmm.com/gh/sre-terraform/tf_security_group.svg?style=svg)](https://cci.dmm.com/gh/sre-terraform/tf_security_group)
 *
 * # About
 * AWS上にSecurityGroupリソースを作成するTerraform module
 *
 * # Components
 * - SecurityGroup
 *
 * # Usage
 * ```ruby
 * module "vpc" {
 *   source = "git::https://git.dmm.com/ogi-yusuke/tf_vpc.git?ref=v1.0.0"
 *
 *   name = "myapp"
 * }
 *
 * module "web_sg" {
 *   source = "git::https://git.dmm.com/ogi-yusuke/tf_security_group.git?ref=v1.0.0"
 *
 *   vpc_id = "${module.vpc.vpc_id}"
 *
 *   name        = "myapp-web"
 *   description = "myapp web"
 *
 *   ingress_with_cidr_block_rules = [
 *     {
 *       cidr_blocks = "0.0.0.0/0"
 *       from_port   = 80
 *       to_port     = 80
 *       protocol    = "tcp"
 *       description = "Allow all IP at 80 port"
 *     },
 *     {
 *       cidr_blocks = "0.0.0.0/0"
 *       from_port   = 22
 *       to_port     = 22
 *       protocol    = "tcp"
 *       description = "Allow all IP at 22 port"
 *     },
 *   ]
 * }
 *
 * module "mysql_sg" {
 *   source = "git::https://git.dmm.com/ogi-yusuke/tf_security_group.git?ref=v1.0.0"
 *
 *   vpc_id = "${module.vpc.vpc_id}"
 *
 *   name        = "myapp-mysql"
 *   description = "myapp mysql"
 *
 *   number_of_computed_ingress_with_source_security_group_rules = 1
 *
 *   ingress_with_security_group_rules = [
 *     {
 *       from_port                = 3306
 *       to_port                  = 3306
 *       protocol                 = "tcp"
 *       source_security_group_id = "${module.web_sg.sg_id}"
 *       description              = "Allow Web Securiry Group at 3306 port"
 *     },
 *   ]
 * }
 * ```
 *
 * ## Simple
 * ```ruby
 * module "vpc" {
 *   source = "git::https://git.dmm.com/ogi-yusuke/tf_vpc.git?ref=v1.0.0"
 *
 *   name = "myapp"
 * }
 *
 * module "web_sg" {
 *   source = "git::https://git.dmm.com/ogi-yusuke/tf_security_group.git?ref=v1.0.1"
 *
 *   vpc_id = "${module.vpc.vpc_id}"
 *
 *   name        = "myapp"
 *
 *   ingress = [
 *     {
 *       cidr_blocks = "0.0.0.0/0"
 *       port        = 80
 *     },
 *   ]
 * }
 * ```
 *
 */

locals {
  description = "${var.description != "" ? var.description : var.name }"
}

resource "aws_security_group" "this" {
  name        = "${var.name}"
  description = "${local.description}"
  vpc_id      = "${var.vpc_id}"

  tags = "${merge(map("Name", format("%s", var.name)), var.tags)}"
}

#########################
# Ingress Rule
#########################
resource "aws_security_group_rule" "ingress" {
  count = "${length(var.ingress)}"

  type = "ingress"

  security_group_id = "${aws_security_group.this.id}"

  cidr_blocks = "${split(",", lookup(var.ingress[count.index], "cidr_blocks"))}"

  from_port   = "${lookup(var.ingress[count.index], "port")}"
  to_port     = "${lookup(var.ingress[count.index], "port")}"
  protocol    = "tcp"
  description = ""
}

resource "aws_security_group_rule" "ingress_with_cidr_block" {
  count = "${length(var.ingress_with_cidr_block_rules)}"

  type = "ingress"

  security_group_id = "${aws_security_group.this.id}"

  cidr_blocks = "${split(",", lookup(var.ingress_with_cidr_block_rules[count.index], "cidr_blocks"))}"

  from_port   = "${lookup(var.ingress_with_cidr_block_rules[count.index], "from_port")}"
  to_port     = "${lookup(var.ingress_with_cidr_block_rules[count.index], "to_port")}"
  protocol    = "${lookup(var.ingress_with_cidr_block_rules[count.index], "protocol")}"
  description = "${lookup(var.ingress_with_cidr_block_rules[count.index], "description")}"
}

resource "aws_security_group_rule" "ingress_with_security_group" {
  count = "${var.number_of_computed_ingress_with_source_security_group_rules}"

  type = "ingress"

  security_group_id = "${aws_security_group.this.id}"

  source_security_group_id = "${lookup(var.ingress_with_security_group_rules[count.index], "source_security_group_id")}"

  from_port   = "${lookup(var.ingress_with_security_group_rules[count.index], "from_port")}"
  to_port     = "${lookup(var.ingress_with_security_group_rules[count.index], "to_port")}"
  protocol    = "${lookup(var.ingress_with_security_group_rules[count.index], "protocol")}"
  description = "${lookup(var.ingress_with_security_group_rules[count.index], "description")}"
}

#########################
# Egress Rule
#########################
resource "aws_security_group_rule" "egress" {
  type = "egress"

  security_group_id = "${aws_security_group.this.id}"

  cidr_blocks = ["0.0.0.0/0"]

  from_port = 0
  to_port   = 0
  protocol  = "-1"
}
