# GitHub Actions deploy role, trusted through the account's existing (shared)
# GitHub OIDC provider, which is referenced here and never managed. Only this
# repository's production-environment jobs or v* tag workflows may assume it,
# and it may only sync the two site buckets and invalidate the two distributions.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  sites = {
    marketing = module.marketing_site
    game      = module.game_site
  }
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    sid     = "GitHubActionsProductionOrReleaseTag"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:environment:${var.github_environment}",
        "repo:${var.github_repository}:ref:refs/tags/v*",
      ]
    }
  }
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "ListSiteBuckets"
    actions   = ["s3:ListBucket"]
    resources = [for s in local.sites : s.bucket_arn]
  }

  statement {
    sid       = "SyncSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [for s in local.sites : "${s.bucket_arn}/*"]
  }

  statement {
    sid       = "EncryptUploadsWithSiteKeys"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [for s in local.sites : s.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.us-east-1.amazonaws.com"]
    }
  }

  statement {
    sid       = "InvalidateSiteDistributions"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [for s in local.sites : s.distribution_arn]
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "mechapilot-github-deploy"
  description          = "GitHub Actions deploys of the mechafighter.com sites"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-static-sites"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
