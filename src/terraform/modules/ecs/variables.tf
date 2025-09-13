variable "cluster_name" {}
variable "vpc_id" {}
variable "subnets" { type = list(string) }
variable "alb_sg_id" {}               # ALB security group ID
variable "nodered_ecr_url" {}
variable "mqtt_ecr_url" {}
variable "nodejs_app_ecr_url" {}
variable "nodered_tg_arn" {}          # from ALB module
variable "nodejs_app_tg_arn" {}       # from ALB module