variable "project_name" { type = string }
variable "aws_region"   { type = string }
variable "ecr_repository" { type = string }
variable "dockerhub_username" { type = string }
variable "dockerhub_password" { type = string }
variable "github_owner"  { type = string }
variable "github_repo"   { type = string }
variable "github_branch" { type = string }
variable "github_token"  { type = string }
variable "buildspec_path" {
  type    = string
  default = "buildspec.yml"
}
