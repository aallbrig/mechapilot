output "policy_json" {
  description = "Assume-role (trust) policy document, as JSON."
  value       = jsonencode(local.policy)
}

output "subject_pattern" {
  description = "The exact (StringEquals) subject the token's sub claim must equal."
  value       = local.subject
}
