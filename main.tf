provider "aws" {
  region = "ap-northeast-1"
}

locals {
  name                       = "ishocon2"
  cidr                       = "10.0.0.0/16"
  vpc_single_nat_gateway     = true
  vpc_one_nat_gateway_per_az = true
  mysql_instance_class       = "db.t2.medium"
  mysql_deletion_protection  = false
  firebase_url               = ""
  database_name              = "ishocon2"
  database_username            = "ishocon2"
  database_password            = "ishocon2ishocon2"
}

module "vpc" {
  source = "./modules/vpc"

  name = "${local.name}"
  cidr = "${local.cidr}"

  public_subnets = [
    "${cidrsubnet(local.cidr, 3, 0)}",
    "${cidrsubnet(local.cidr, 3, 1)}",
    "${cidrsubnet(local.cidr, 3, 2)}",
  ]

  private_subnets = [
    "${cidrsubnet(local.cidr, 3, 4)}",
    "${cidrsubnet(local.cidr, 3, 5)}",
    "${cidrsubnet(local.cidr, 3, 6)}",
  ]

  single_nat_gateway     = "false"
  one_nat_gateway_per_az = "true"
}

module "alb_sg" {
  source = "./modules/security_group"

  vpc_id      = "${module.vpc.vpc_id}"
  name        = "${local.name}-alb"
  description = "basic alb rule"

  ingress_with_cidr_block_rules = [
    {
      cidr_blocks = "0.0.0.0/0"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow all IP at 80 port"
    },
  ]
}

module "alb" {
  source = "./modules/alb"

  name            = "${local.name}"
  subnets         = "${module.vpc.public_subnets}"
  security_groups = ["${module.alb_sg.sg_id}"]
}

output "alb_url" {
    value = "${module.alb.alb_dns_name}"
}

resource "aws_ecs_cluster" "cluster" {
  name = "${local.name}"
}

data "template_file" "container_definitions" {
  template = "${file("container_definitions.json")}"

  vars {
    region                      = "ap-northeast-1"
    name                        = "${local.name}"
    loadbalancer_container_port = "80"
    firebase_url                = "${local.firebase_url}"
    database_address            = "${module.mysql.endpoint}"
    database_username               = "${local.database_username}"
    database_password           = "${local.database_password}"
  }
}

module "svc_sg" {
  source = "modules/security_group"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-service"
  description = "service rule"

  ingress_with_cidr_block_rules = [
    {
      cidr_blocks = "0.0.0.0/0"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow all IP at 80 port"
    },
  ]
}

module "ecs_service" {
  source = "modules/ecs_service"

  name = "${local.name}"

  vpc_id  = "${module.vpc.vpc_id}"
  subnets = "${module.vpc.private_subnets}"

  ecs_cluster_name        = "${aws_ecs_cluster.cluster.name}"
  main_container_name     = "bench"
  task_log_names          = ["ecs"]
  service_security_groups = ["${module.svc_sg.sg_id}"]
  container_definitions   = "${data.template_file.container_definitions.rendered}"
  alb_listener_arn        = "${module.alb.http_listener_arn}"
  alb_health_check_path   = "/"
}

module "mysql_sg" {
  source = "./modules/security_group"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-mysql"
  description = "${local.name} mysql"

  ingress_with_cidr_block_rules = [
    {
      cidr_blocks = "${local.cidr}"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "Allow access within VPC at 3306 port"
    },
  ]
}

module "mysql" {
  source = "./modules/aurora"

  name = "${local.name}"

  subnets            = "${module.vpc.private_subnets}"
  security_group_ids = ["${module.mysql_sg.sg_id}"]

  # DB接続情報
  database_name   = "${local.database_name}"
  master_username = "${local.database_username}"
  master_password = "${local.database_password}"

  # インスタンスクラス
  instance_class = "${local.mysql_instance_class}"

  # 削除保護
  deletion_protection = "${local.mysql_deletion_protection}"
}
