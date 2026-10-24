# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = ["sts.amazonaws.com"]
  tags            = {}
  tags_all        = {}
  thumbprint_list = ["ab9d0263244dd0326eb67015705a667e79cfe998"]
  url             = "https://token.actions.githubusercontent.com"
}

# __generated__ by Terraform from "GitHubActionsECRPush:GitHubActionsECRPushPolicy"
resource "aws_iam_role_policy" "github_ecr" {
  name = "GitHubActionsECRPushPolicy"
  policy = jsonencode({
    Statement = [{
      Action   = "ecr:GetAuthorizationToken"
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECRAuthorization"
      }, {
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
      Effect   = "Allow"
      Resource = "arn:aws:ecr:us-east-1:205501819379:repository/backend-repo"
      Sid      = "ECRPush"
    }]
    Version = "2012-10-17"
  })
  role = "GitHubActionsECRPush"
}

# __generated__ by Terraform from "GitHubActionsECRPush"
resource "aws_iam_role" "github_actions" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:benitauj-debug@298327020/movie-backend@1363976261:ref:refs/heads/main"
        }
      }
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::205501819379:oidc-provider/token.actions.githubusercontent.com"
      }
    }]
    Version = "2012-10-17"
  })
  description           = "Allow the GitHub Actions to push the movie backend Docker image to Amazon ECR."
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "GitHubActionsECRPush"
  path                  = "/"
  permissions_boundary  = null
  tags                  = {}
  tags_all              = {}
}
