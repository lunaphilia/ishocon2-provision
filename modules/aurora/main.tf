/**
 * tf_aurora
 * ---
 *
 * [![CircleCI](https://cci.dmm.com/gh/sre-terraform/tf-aurora.svg?style=svg)](https://cci.dmm.com/gh/sre-terraform/tf-aurora)
 *
 * # About
 * AWS上にAuroraを作成するTerraform module
 *
 * # Components
 * - RDS Cluster
 * - RDS Instance
 * - DB Subnet Group
 * - Application AutoScaling
 * - CloudWatch Logs
 *     - DB Audit
 *     - DB Error
 *     - DB General
 *     - DB Slow query
 * - IAM
 *     - Enhanced Monitoring
 *     - DB Audit
 * - Cluster ParameterGroup
 * - DB ParameterGroup
 *
 * # Update README
 * ```
 * $ terraform-docs markdown ./ > README.md
 * ```
 *
 * # Usage
 * ## Aurora MySQL
 * SSM Parameterでアクセス情報を管理し、Aurora MySQL 5.7.12を起動する例。
 *
 * ```
 * $ SERVICE_NAME=myapp
 * $ aws ssm put-parameter --name "/${SERVICE_NAME}/db/name" --value <DATABASE NAME> --type String
 * $ aws ssm put-parameter --name "/${SERVICE_NAME}/db/username" --value <MASTER USERNAME> --type String
 * $ aws ssm put-parameter --name "/${SERVICE_NAME}/db/password" --value <MASTER PASSWORD> --type String
 * ```
 *
 * ```ruby
 * local {
 *   name = "myapp"
 * }
 *
 * module "vpc" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf_vpc.git?ref=v1.0.0"
 * }
 *
 * module "aurora_sg" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf_security_group.git?ref=v1.0.0"
 *
 *   vpc_id = "${module.vpc.vpc_id}"
 *
 *   description = "myapp aurora rule"
 *
 *   ingress_with_cidr_block_rules = [
 *     {
 *       cidr_block  = "10.0.0.0/0"
 *       from_port   = 3306
 *       to_port     = 3306
 *       protocol    = "tcp"
 *       description = "Allow access from within VPC"
 *     },
 *   ]
 * }
 *
 * data "aws_ssm_parameter" "database_name" {
 *   name = "/${local.name}/db/name"
 * }
 *
 * data "aws_ssm_parameter" "master_username" {
 *   name = "/${local.name}/db/username"
 * }
 *
 * data "aws_ssm_parameter" "master_password" {
 *   name = "/${local.name}/db/password"
 * }
 *
 * module "mysql" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf_aurora.git?ref=v1.0.0"
 *
 *   subnets            = "${module.vpc.private_subnets}"
 *   security_group_ids = ["${module.mysql_sg.sg_id}"]
 *
 *   database_name   = "${data.aws_ssm_parameter.database_name.value}"
 *   master_username = "${data.aws_ssm_parameter.master_username.value}"
 *   master_password = "${data.aws_ssm_parameter.master_password.value}"
 *
 *   instance_class = "db.r4.large"
 *
 *   # 削除保護の有効化
 *   deletion_protection = true
 *
 *   # インスタンスを3-9台用意する
 *   replica_scale_max = 8
 *   replica_scale_min = 2
 * }
 * ```
 *
 * ## PostgreSQL
 * ```
 * module "aurora_sg" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf_security_group.git?ref=v1.0.0"
 *
 *   vpc_id = "${module.vpc.vpc_id}"
 *
 *   description = "postgres aurora rule"
 *
 *   ingress_with_cidr_block_rules = [
 *     {
 *       cidr_block  = "10.0.0.0/0"
 *       from_port   = 5432
 *       to_port     = 5432
 *       protocol    = "tcp"
 *       description = "Allow access from within VPC"
 *     },
 *   ]
 * }
 *
 * module "postgres" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf_aurora.git?ref=v1.0.0"
 *
 *   subnets            = "${module.vpc.private_subnets}"
 *   security_group_ids = ["${module.postgres_sg.sg_id}"]
 *
 *   engine                          = "aurora-postgresql"
 *   engine_version                  = "10.6"
 *   port                            = 5432
 *   db_cluster_parameter_group_name = "default.postgres10"
 *   db_parameter_group_name         = "default.postgres10"
 *
 *   database_name   = "${data.aws_ssm_parameter.database_name.value}"
 *   master_username = "${data.aws_ssm_parameter.master_username.value}"
 *   master_password = "${data.aws_ssm_parameter.master_password.value}"
 *
 *   instance_class = "db.r4.large"
 *
 *   # 削除保護の有効化
 *   deletion_protection = true
 *
 *   # インスタンスを3-9台用意する
 *   replica_scale_max = 8
 *   replica_scale_min = 2
 * }
 * ```
 *
 * # Tips
 * ## 課金額を抑えるために
 * Aurora用に作成される以下のロググループの失効期間をプロジェクトに合わせて設定することを推奨
 *
 * - `/aws/rds/cluster/${var.name}/audit`
 * - `/aws/rds/cluster/${var.name}/error`
 * - `/aws/rds/cluster/${var.name}/general`
 * - `/aws/rds/cluster/${var.name}/slowquery`
 *
 * # Reference
 * - [terraform-aws-modules/terraform-aws-rds-aurora: Terraform module which creates RDS Aurora resources on AWS](https://github.com/terraform-aws-modules/terraform-aws-rds-aurora)
 *
 */

#########################
# SubnetGroup
#########################
resource "aws_db_subnet_group" "this" {
  name        = "${var.name}"
  description = "${var.name}"
  subnet_ids  = ["${var.subnets}"]

  tags = "${merge(map("Name", var.name), var.tags)}"
}

#########################
# Cluster
#########################
resource "random_string" "final_snapshot_suffix" {
  special = false
  upper   = false
  length  = 8
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name}"

  deletion_protection = "${var.deletion_protection}"

  db_subnet_group_name   = "${aws_db_subnet_group.this.name}"
  vpc_security_group_ids = ["${var.security_group_ids}"]

  db_cluster_parameter_group_name = "${var.db_cluster_parameter_group_name != "" ? var.db_cluster_parameter_group_name : aws_rds_cluster_parameter_group.basic.name}"

  engine         = "${var.engine}"
  engine_version = "${var.engine_version}"
  port           = "${var.port}"

  database_name   = "${var.database_name}"
  master_username = "${var.master_username}"
  master_password = "${var.master_password}"

  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  backup_retention_period = "${var.backup_retention_period}"
  preferred_backup_window = "${var.preferred_backup_window}"

  final_snapshot_identifier = "${var.name}-final-${random_string.final_snapshot_suffix.result}"
  skip_final_snapshot       = false

  preferred_maintenance_window = "${var.preferred_maintenance_window}"

  apply_immediately = "${var.apply_immediately}"

  tags = "${var.tags}"
}

#########################
# DB Instance
#########################
resource "aws_rds_cluster_instance" "this" {
  count = "${var.number_of_instance}"

  identifier         = "${format("%s-%d", var.name, count.index)}"
  cluster_identifier = "${aws_rds_cluster.this.id}"

  engine         = "${var.engine}"
  engine_version = "${var.engine_version}"

  instance_class = "${var.instance_class}"

  db_parameter_group_name = "${var.db_parameter_group_name != "" ? var.db_parameter_group_name : aws_db_parameter_group.basic.name}"

  db_subnet_group_name = "${aws_db_subnet_group.this.name}"

  preferred_maintenance_window = "${var.preferred_maintenance_window}"

  apply_immediately          = "${var.apply_immediately}"
  auto_minor_version_upgrade = "${var.auto_minor_version_upgrade}"

  monitoring_role_arn = "${join("", aws_iam_role.rds_enhanced_monitoring.*.arn)}"
  monitoring_interval = "${var.monitoring_interval}"

  performance_insights_enabled = "${var.performance_insights_enabled}"

  tags = "${var.tags}"
}

#########################
# Enhanced Monitoring IAM Role
#########################
data "aws_iam_policy_document" "monitoring_rds_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.name}-aurora-enhanced-monitoring"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "monitoring.rds.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = "${var.tags}"
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = "${aws_iam_role.rds_enhanced_monitoring.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

#########################
# Application AutoScaling
#########################
resource "aws_appautoscaling_target" "read_replica_count" {
  max_capacity       = "${var.replica_scale_max}"
  min_capacity       = "${var.replica_scale_min}"
  resource_id        = "cluster:${aws_rds_cluster.this.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"
}

resource "aws_appautoscaling_policy" "autoscaling_read_replica_count" {
  name               = "cpu-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "cluster:${aws_rds_cluster.this.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }

    scale_in_cooldown  = "${var.replica_scale_in_cooldown}"
    scale_out_cooldown = "${var.replica_scale_out_cooldown}"
    target_value       = "${var.replica_scale_cpu}"
  }

  depends_on = ["aws_appautoscaling_target.read_replica_count", "aws_rds_cluster.this"]
}
