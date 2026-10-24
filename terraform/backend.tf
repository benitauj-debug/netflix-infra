terraform {
  backend "s3" {
    bucket       = "benita-netflix-tfstate-9379"
    key          = "netflix/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}