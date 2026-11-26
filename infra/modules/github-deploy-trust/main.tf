# The trust policy for a GitHub Actions deploy role, as a pure function: no
# provider, no API calls, so it can be rendered and tested offline
# (tests/shell/test_deploy_trust).
#
# It fails closed. The repository's OIDC subject must be customized to
# include_claim_keys = ["repo", "environment", "ref"] with immutable subjects,
# which makes the sub claim
#   repo:<owner>@<owner-id>/<repo>@<repo-id>:environment:<env>:ref:<ref>
# A token in any other format (default subject, branch ref, missing
# environment, missing tag) matches nothing, so the role can't be assumed.

locals {
  subject = join(":", [
    "repo",
    "${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}",
    "environment",
    var.github_environment,
    "ref",
    "refs/tags/${var.tag_pattern}",
  ])

  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "GitHubActionsReleaseTagInProductionEnvironment"
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.oidc_provider_arn }
        Condition = {
          StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
          StringLike   = { "token.actions.githubusercontent.com:sub" = local.subject }
        }
      },
    ]
  }
}
