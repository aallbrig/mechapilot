output "state_bucket_name" {
  description = "Bucket to put in infra/stacks/prod/backend.hcl."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_region" {
  description = "Region to put in infra/stacks/prod/backend.hcl."
  value       = aws_s3_bucket.state.region
}
