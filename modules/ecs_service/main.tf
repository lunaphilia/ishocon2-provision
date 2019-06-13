/**
 * tf-ecs-service
 * ---
 *
 * [![CircleCI](https://cci.dmm.com/gh/sre-terraform/tf-ecs-service.svg?style=svg)](https://cci.dmm.com/gh/sre-terraform/tf-ecs-service)
 *
 * # About
 * TerraformによるECS Service管理用コード
 *
 * # Components
 * - Task Definition
 * - LB Target Group
 * - LB Listener Rule
 * - ECS Service
 * - Application AutoScaling
 *
 * # Update README
 * ```
 * $ terraform-docs markdown ./ > README.md
 * ```
 *
 * # Usage
 * 前提として、ALB, ECS Cluster、ECRが作成されていること。
 *
 * ## ECR
 * ```
 * ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
 * $(aws ecr get-login --no-include-email --region ap-northeast-1)
 * docker build -t nginx .
 * docker tag nginx:latest ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/nginx:latest
 * docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/nginx:latest
 * ```
 *
 * ## container_definitions.json
 * ```json
 * [
 *   {
 *     "name": "nginx",
 *     "image": "nginx",
 *     "cpu": 0,
 *     "memory": 128,
 *     "portMappings": [
 *       {
 *         "containerPort": 80,
 *         "hostPort": 80,
 *         "protocol": "tcp"
 *       }
 *     ],
 *     "logConfiguration": {
 *       "logDriver": "awslogs",
 *       "options": {
 *         "awslogs-region": "${region}",
 *         "awslogs-group": "/${name}/ecs",
 *         "awslogs-stream-prefix": "nginx"
 *       }
 *     }
 *   }
 * ]
 * ```
 *
 * ## main.tf
 * ```ruby
 * module "ecs_service" {
 *   source = "git::https://git.dmm.com/sre-terraform/tf-vpc.git?ref=v1.1.0"
 *
 *   name = "${var.name}"
 *
 *   remote_state_bucket = "my-terraform-state-bucket"
 *
 *   main_container_name = "nginx"
 *   service_security_groups = ["sg-xxxxxx"]
 *   container_definitions = "${data.template_file.container_definitions.rendered}"
 *   alb_listener_arn = "${data.terraform_remote_state.main.https_listener_arn}"
 * }
 * ```
 */

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  # アカウントID
  account_id = "${data.aws_caller_identity.current.account_id}"

  # プロビジョニングを実行するリージョン
  region = "${data.aws_region.current.name}"

  # ECS Serviceと疎通させるALBのListener
  alb_https_listener_arn = "${var.alb_listener_arn}"
}

#########################
# Task Definition
#########################
resource "aws_ecs_task_definition" "this" {
  family = "${var.name}"

  container_definitions = "${var.container_definitions}"

  cpu                      = "${var.task_cpu}"
  memory                   = "${var.task_memory}"
  network_mode             = "${var.task_network_mode}"
  requires_compatibilities = ["${var.task_requires_compatibilities}"]

  task_role_arn      = "${aws_iam_role.task_execution.arn}"
  execution_role_arn = "${aws_iam_role.task_execution.arn}"

  tags = "${merge(map("Name", format("%s", var.name)), var.tags)}"
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name}-TaskExecution"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "task_execution" {
  role = "${aws_iam_role.task_execution.id}"

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
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ],
      "Resource": [
        "arn:aws:ssm:${local.region}:${local.account_id}:parameter/*",
        "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:*",
        "arn:aws:kms:${local.region}:${local.account_id}:key/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = "${aws_iam_role.task_execution.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "this" {
  count = "${length(var.task_log_names)}"

  name              = "/${var.name}/${var.task_log_names[count.index]}"
  retention_in_days = "${var.task_log_rotate_day}"
}

#########################
# Service
#########################
resource "aws_ecs_service" "this" {
  name = "${var.name}"

  cluster                           = "${var.ecs_cluster_name}"
  task_definition                   = "${aws_ecs_task_definition.this.arn}"
  launch_type                       = "${var.task_requires_compatibilities}"
  desired_count                     = "${var.service_desired_count}"
  health_check_grace_period_seconds = "${var.service_initial_delay_seconds}"

  network_configuration {
    subnets          = ["${var.subnets}"]
    security_groups  = ["${var.service_security_groups}"]
    assign_public_ip = "${var.service_enable_assign_public_ip}"
  }

  deployment_controller {
    type = "${var.service_deployment_controller}"
  }

  load_balancer = [
    {
      target_group_arn = "${aws_lb_target_group.this.arn}"
      container_name   = "${var.main_container_name}"
      container_port   = "${var.port}"
    },
  ]

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  tags = "${var.tags}"

  lifecycle {
    ignore_changes = ["desired_count", "load_balancer"]
  }
}

resource "aws_lb_target_group" "this" {
  #XXX 乱数を生成せずにnameプロパティを使用するとALBへの依存が発生し、apply後に当該Moduleだけ削除することができなくなる https://github.com/terraform-providers/terraform-provider-aws/issues/636

  # name = "${var.name}"

  vpc_id = "${var.vpc_id}"
  port   = "${var.port}"

  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    port                = "${var.port}"
    path                = "${var.alb_health_check_path}"
    matcher             = "${var.alb_health_check_matcher}"
  }

  lifecycle {
    create_before_destroy = true

    #XXX: nameプロパティを使用する場合はコメントアウト
    # ignore_changes        = ["name"]
  }

  tags = "${merge(map("Name", format("%s", var.name)), var.tags)}"
}

resource "aws_alb_listener_rule" "this" {
  listener_arn = "${local.alb_https_listener_arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.this.id}"
  }

  condition {
    field  = "${var.alb_listener_condition_field}"
    values = ["${var.alb_listener_condition_values}"]
  }

  lifecycle {
    ignore_changes = ["action"]
  }
}

#########################
# Application AutoScaling
#########################
resource "aws_appautoscaling_target" "this" {
  min_capacity       = "${var.scale_min_capacity}"
  max_capacity       = "${var.scale_max_capacity}"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.this.name}"
  role_arn           = "${aws_iam_role.appautoscaling.arn}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = ["role_arn"]
  }
}

resource "aws_appautoscaling_policy" "this" {
  name               = "${var.name}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "${var.scale_predefined_metric_type}"
    }

    scale_in_cooldown  = "${var.scale_in_cooldown}"
    scale_out_cooldown = "${var.scale_out_cooldown}"
    target_value       = "${var.scale_threshold}"
  }

  depends_on = ["aws_appautoscaling_target.this"]
}

resource "aws_iam_role" "appautoscaling" {
  name = "${var.name}-AppAutoScaling"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "appautoscaling" {
  role       = "${aws_iam_role.task_execution.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}
