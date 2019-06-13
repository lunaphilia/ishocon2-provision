variable "name" {
  description = "アプリケーションに使用する命名。"
  default     = "myapp"
}

variable "region" {
  description = "VPCを配置するリージョン"
  default     = "ap-northeast-1"
}

variable "azs" {
  description = "サブネットを配置するAZ。regionと対応させる必要あり"
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "tags" {
  description = "各リソースに付与するtag"
  default     = {}
}

variable "cidr" {
  description = "VPCのCIDR"
  default     = "10.0.0.0/16"
}

variable "public_subnet_suffix" {
  description = "パブリックサブネットのNameタグのSuffix"
  default     = "public"
}

variable "public_subnets" {
  description = "パブリックサブネットのレンジ。azsと同じ数にする必要あり"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_suffix" {
  description = "プライベートサブネットのNameタグのSuffix"
  default     = "private"
}

variable "private_subnets" {
  description = "プライベートサブネットのレンジ。azsと同じ数にする必要あり"
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "enable_dns" {
  description = "AmazonのDNSを名前解決に使用するか"
  default     = true
}

variable "flowlog_retention_in_days" {
  description = "VPC FlowLogの保持期間(日)"
  default     = 7
}

variable "single_nat_gateway" {
  description = "NAT Gatewayを1つ作成する。開発環境もしくは節約を目的とする場合意外は非推奨"
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "NAT Gatewayを `azs` で設定した数作成する。本番・ステージング環境時に設定する"
  default     = false
}

variable "nat_ips" {
  description = "NAT Gatewayに関連づけるElastic IPのID。指定する場合はNAT Gatewayの数だけElastic IPを指定する必要がある"
  default     = []
}
