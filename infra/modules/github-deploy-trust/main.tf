# The trust policy for a GitHub Actions deploy role, as a pure function: no
# provider, no API calls, so it can be rendered and tested offline
# (tests/shell/test_deploy_trust).
#
# It fails closed. The repository's OIDC subject must be customized to
# include_claim_keys = ["repo", "ref", "environment"] with immutable subjects,
# which makes the sub claim
#   repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:<ref>:environment:<env>
# The role trusts exactly one subject, compared with StringEquals (no
# wildcards): the main branch, in the production environment (#31). Deploys
# are dispatched from main (deploy.yml); a tag, another branch, a pull request
# or another environment matches nothing, and a token in any other format
# (default subject, other key order, missing environment) matches nothing, so
# the trust fails closed. With no wildcard there is nothing for an
# environment name like "x:environment:production" to splice into.

locals {
  subject = join(":", [
    "repo",
    "${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}",
    "ref",
    "refs/heads/main",
    "environment",
    var.github_environment,
  ])

  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "GitHubActionsMainInProductionEnvironment"
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.oidc_provider_arn }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.subject
          }
        }
      },
    ]
  }
}
