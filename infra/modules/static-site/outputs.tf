output "bucket_name" {
  description = "Name of the site bucket (the deploy target)."
  value       = aws_s3_bucket.site.bucket
}

output "bucket_arn" {
  description = "ARN of the site bucket."
  value       = aws_s3_bucket.site.arn
}

output "kms_key_arn" {
  description = "ARN of the key that encrypts the site bucket; uploads need kms:GenerateDataKey on it."
  value       = aws_kms_key.site.arn
}

output "distribution_id" {
  description = "CloudFront distribution ID (for cache invalidations)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "The distribution's *.cloudfront.net name, usable for checks before the DNS cutover."
  value       = aws_cloudfront_distribution.this.domain_name
}
