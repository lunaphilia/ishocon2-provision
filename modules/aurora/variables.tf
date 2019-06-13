variable "name" {
  description = "アプリケーションに使用する命名。	"
  default     = "myapp"
}

variable "tags" {
  description = "各リソースに付与するtag"
  default     = {}
}

variable "subnets" {
  description = "ALBを配置するサブネット一覧 e.g. ['subnet-1a2b3c4d','subnet-1a2b3c4e','subnet-1a2b3c4f'"
  type        = "list"
}

variable "security_group_ids" {
  description = "ALBに登録するセキュリティグループ一覧 e.g. ['sg-edcd9784','sg-edcd9785']"
  type        = "list"
}

variable "engine" {
  description = "Auroraエンジンタイプ"
  default     = "aurora-mysql"
}

variable "engine_version" {
  description = "Auroraのバージョン"
  default     = "5.7.mysql_aurora.2.04.3"
}

#########################
# Cluster
#########################
variable "port" {
  description = "接続を許可するポート"
  default     = 3306
}

variable "database_name" {
  description = "デフォルトで作成されるデータベース名"
}

variable "master_username" {
  description = "デフォルトで作成されるマスターユーザーのマスタユーザー名"
}

variable "master_password" {
  description = "デフォルトで作成されるマスターユーザーのパスワード"
}

variable "db_cluster_parameter_group_name" {
  description = "既存のDB Cluster 用パラメータグループ名。何も設定されていない場合、推奨されるパラメータグループが作成される"
  default     = ""
}

variable "db_parameter_group_name" {
  description = "既存のDB用パラメータグループ名。何も設定されていない場合、推奨されるパラメータグループが作成される"
  default     = ""
}

variable "deletion_protection" {
  description = "データベースの削除保護"
  default     = false
}

variable "backup_retention_period" {
  description = "バックアップの執行期間 (days)"
  default     = 7
}

variable "preferred_backup_window" {
  description = "バックアップを取得する時間 (UTC)"
  default     = "06:30-07:30"
}

variable "preferred_maintenance_window" {
  description = "メンテナンスを許可する時間 (UTC)"
  default     = "Tue:05:00-Tue:06:00"
}

variable "apply_immediately" {
  description = "DBへ変更があった際に「直ちに変更する(再起動が発生する可能性あり)」を許可するか否か。"
  default     = false
}

#########################
# DB Instance
#########################
variable "instance_class" {
  description = "インスタンスタイプ"
  default     = "db.t3.small"
}

variable "monitoring_interval" {
  description = "拡張モニタリングのインターバル (sec)"
  default     = 30
}

variable "auto_minor_version_upgrade" {
  description = "自動的にマイナーバージョンアップを実行する"
  default     = true
}

variable "number_of_instance" {
  description = "インスタンスを作成する台数"
  default     = 3
}

variable "performance_insights_enabled" {
  description = "Perfomance Insights の有効化"
  default     = false
}

#########################
# Application AutoScaling
#########################
variable "replica_scale_max" {
  description = "指定されているインスタンス台数より何台増やせるか"
  default     = 0
}

variable "replica_scale_min" {
  description = "指定されているインスタンス台数より何台減らせるか"
  default     = 0
}

variable "replica_scale_in_cooldown" {
  description = "スケールイン後のクールダウン"
  default     = 300
}

variable "replica_scale_out_cooldown" {
  description = "スケールアウト後のクールダウン"
  default     = 300
}

variable "replica_scale_cpu" {
  description = "CPU使用率のしきい値"
  default     = 70
}

#########################
# Parameter Group
#########################
variable "time_zone" {
  description = "Auroraに設定するタイムゾーン"
  default     = "Asia/Tokyo"
}
