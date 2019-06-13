/**
 * tf-alb
 * ---
 *
 * [![CircleCI](https://cci.dmm.com/gh/sre-terraform/tf-alb?style=svg)](https://cci.dmm.com/gh/sre-terraform/tf-alb)
 *
 * # Usage
 * ```ruby
 * module "vpc" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf-vpc.git?ref=v1.0.0"
 * }
 *
 * module "alb_sg" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"
 *
 *   vpc_id = "${module.vpc.vpc_id}"
 *
 *   name        = "myapp-alb"
 *   description = "basic alb rule"
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
 *       from_port   = 443
 *       to_port     = 443
 *       protocol    = "tcp"
 *       description = "Allow all IP at 443 port"
 *     },
 *   ]
 * }
 *
 * module "acm" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf-acm.git?ref=v1.0.0"
 *
 *   domains = ["example.com"]
 * }
 *
 * module "alb" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf-alb.git?ref=v1.2.0"
 *
 *   subnets         = "${module.vpc.public_subnets}"
 *   security_groups = ["${module.alb_sg.sg_id}"]
 *
 *   https_listener_count = 1
 *   acm_arn              = "module.acm.acm_arn"
 * }
 * ```
 */

#########################
# Access Log Bucket
#########################
# S3 Bucketの命名は一意である必要があるため、Suffixにuuidを付与する
locals {
  s3_bucket_name = "${var.name}-alb-log-${random_string.s3_suffix.result}"
}

resource "random_string" "s3_suffix" {
  special = false
  upper   = false
  length  = 8
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "${local.s3_bucket_name}"

  force_destroy = true

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::127311923021:root",
          "arn:aws:iam::033677994240:root",
          "arn:aws:iam::027434742980:root",
          "arn:aws:iam::797873946194:root",
          "arn:aws:iam::985666609251:root",
          "arn:aws:iam::156460612806:root",
          "arn:aws:iam::054676820928:root",
          "arn:aws:iam::652711504416:root",
          "arn:aws:iam::582318560864:root",
          "arn:aws:iam::600734575887:root",
          "arn:aws:iam::114774131450:root",
          "arn:aws:iam::783225319266:root",
          "arn:aws:iam::718504428378:root",
          "arn:aws:iam::507241528517:root"
        ]
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${local.s3_bucket_name}/*"
    }
  ]
}
EOF
}

#########################
# Application LoadBalancer
#########################
resource "aws_lb" "this" {
  load_balancer_type = "application"

  name            = "${var.name}"
  security_groups = ["${var.security_groups}"]
  subnets         = ["${var.subnets}"]

  idle_timeout = "${var.idle_timeout}"
  internal     = "${var.internal}"

  tags = "${merge(map("Name", var.name), var.tags)}"

  access_logs {
    enabled = true
    bucket  = "${aws_s3_bucket.log_bucket.id}"
  }
}

#########################
# HTTP Listener
#########################
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = "${aws_lb.this.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#########################
# HTTPS Listener
#########################
resource "aws_lb_listener" "https_listener" {
  count = "${var.https_listener_count}"

  load_balancer_arn = "${aws_lb.this.arn}"
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = "${var.acm_arn}"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "ng"
      status_code  = "503"
    }
  }
}
