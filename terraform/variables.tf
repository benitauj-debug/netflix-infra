variable "region" {
  type    = string
  default = "us-east-1"
}

variable "my_ip_cidr" {
  type = string
}

variable "ecr_repo_names" {
  type = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/netflix-k3s.pub"
}