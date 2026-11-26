output "deploy_role_arn" {
  description = "Role for the production deploy workflow (store it as an Actions variable, never in the repo)."
  value       = aws_iam_role.deploy.arn
}

output "marketing_site" {
  description = "Marketing Site deploy targets."
  value = {
    bucket_name              = module.marketing_site.bucket_name
    distribution_id          = module.marketing_site.distribution_id
    distribution_domain_name = module.marketing_site.distribution_domain_name
  }
}

output "game_site" {
  description = "Game Site deploy targets."
  value = {
    bucket_name              = module.game_site.bucket_name
    distribution_id          = module.game_site.distribution_id
    distribution_domain_name = module.game_site.distribution_domain_name
  }
}
