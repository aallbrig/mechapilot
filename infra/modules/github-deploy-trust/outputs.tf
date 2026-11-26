output "policy_json" {
  description = "Assume-role (trust) policy document, as JSON."
  value       = jsonencode(local.policy)
}

output "subject_pattern" {
  description = "The single StringLike pattern the token's sub claim must match."
  value       = local.subject
}
