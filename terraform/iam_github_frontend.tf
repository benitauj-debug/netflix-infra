# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "GithubActionsFrontendECRPush:GitHubActionsFrontendECRPushPolicy"
resource "aws_iam_role_policy" "github_frontend_ecr" {
  name = "GitHubActionsFrontendECRPushPolicy"
  policy = jsonencode({
    Statement = [{
      Action   = "ecr:GetAuthorizationToken"
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECRAuthorization"
      }, {
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
      Effect   = "Allow"
      Resource = "arn:aws:ecr:us-east-1:205501819379:repository/frontend-repo"
      Sid      = "ECRPush"
    }]
    Version = "2012-10-17"
  })
  role = "GithubActionsFrontendECRPush"
}

# __generated__ by Terraform from "GithubActionsFrontendECRPush"
resource "aws_iam_role" "github_frontend" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:benitauj-debug@298327020/movie-frontend@1374589272:ref:refs/heads/main"
        }
      }
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::205501819379:oidc-provider/token.actions.githubusercontent.com"
      }
    }]
    Version = "2012-10-17"
  })
  description           = null
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "GithubActionsFrontendECRPush"
  path                  = "/"
  permissions_boundary  = null
  tags                  = {}
  tags_all              = {}
}
