#########################
# Audit IAM Role
#########################
resource "aws_iam_role" "audit" {
  name = "${var.name}-rds-cluster-audit"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = "${var.tags}"
}

resource "aws_iam_policy" "audit_policy" {
  name = "${var.name}-aurora-audit-policy"

  policy = <<EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnableCreationAndManagementOfRDSCloudwatchLogGroups",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:PutRetentionPolicy"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:/aws/rds/*"
      ]
    },
    {
      "Sid": "EnableCreationAndManagementOfRDSCloudwatchLogStreams",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:/aws/rds/*:log-stream:*"
      ]
    }
  ]
}

EOL
}

resource "aws_iam_policy_attachment" "attach_audit_policy" {
  name       = "${var.name}-attach-audit-policy"
  roles      = ["${aws_iam_role.audit.name}"]
  policy_arn = "${aws_iam_policy.audit_policy.arn}"
}

#########################
# Aurora Parameter Group
#   MySQL 5.7.12
#########################
resource "aws_rds_cluster_parameter_group" "basic" {
  name   = "${var.name}-aurora-mysql5-7"
  family = "aurora-mysql5.7"

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_connection"
    value = "utf8mb4_bin"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_bin"
  }

  parameter {
    name         = "binlog_format"
    value        = "MIXED"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "server_audit_logging"
    value = "1"
  }

  parameter {
    name  = "server_audit_events"
    value = "connect,query,query_dcl,query_ddl,query_dml,table"
  }

  parameter {
    name  = "server_audit_logs_upload"
    value = "1"
  }

  parameter {
    name  = "aws_default_logs_role"
    value = "${aws_iam_role.audit.arn}"
  }

  parameter {
    name  = "time_zone"
    value = "${var.time_zone}"
  }
}

resource "aws_db_parameter_group" "basic" {
  name   = "${var.name}-aurora-mysql5-7"
  family = "aurora-mysql5.7"
}
