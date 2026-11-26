# The trust policy for a GitHub Actions deploy role, as a pure function: no
# provider, no API calls, so it can be rendered and tested offline
# (tests/shell/test_deploy_trust).
#
# It fails closed. The repository's OIDC subject must be customized to
# include_claim_keys = ["repo", "ref", "environment"] with immutable subjects,
# which makes the sub claim
#   repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:<ref>:environment:<env>
# A token in any other format (default subject, other key order, branch ref,
# missing environment, missing tag) matches nothing.
#
# Why this order: ref names cannot contain ":", so the only free text a
# workflow controls is the environment name, and it comes last, after a fixed
# ":environment:". The pattern ends in the literal environment name, and a
# StringNotLike condition rejects any subject with a second ":environment:",
# so an environment named like "x:environment:production" cannot be smuggled
# through the v* wildcard.

locals {
  subject = join(":", [
    "repo",
    "${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}",
    "ref",
    "refs/tags/${var.tag_pattern}",
    "environment",
    var.github_environment,
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
          StringEquals  = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
          StringLike    = { "token.actions.githubusercontent.com:sub" = local.subject }
          StringNotLike = { "token.actions.githubusercontent.com:sub" = "*:environment:*:environment:*" }
        }
      },
    ]
  }
}
