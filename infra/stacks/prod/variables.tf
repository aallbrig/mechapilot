variable "domain" {
  description = "Apex domain of the hosted zone."
  type        = string
  default     = "mechafighter.com"
}

variable "hosted_zone_id" {
  description = "ID of the existing Route 53 hosted zone for the domain (imported; supplied in an untracked tfvars file, never committed)."
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "hosted_zone_id must look like a Route 53 hosted zone ID."
  }
}

variable "hosted_zone_comment" {
  description = "Comment on the existing hosted zone, kept as-is so the import plans no change."
  type        = string
  default     = "HostedZone created by Route53 Registrar"
}

variable "certificate_arn" {
  description = "ARN of the existing ACM certificate in us-east-1 for the apex and wildcard (imported; supplied in an untracked tfvars file, never committed)."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:acm:us-east-1:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn))
    error_message = "certificate_arn must be an ACM certificate ARN in us-east-1."
  }
}

variable "marketing_bucket_name" {
  description = "Name of the new, private bucket for the Marketing Site."
  type        = string
}

variable "game_bucket_name" {
  description = "Name of the new, private bucket for the Game Site."
  type        = string
}

variable "marketing_aliases_enabled" {
  description = "Attach the apex and www names to the new Marketing Site distribution and point DNS at it. Keep false until the 2022 distribution has released the names (infra/README.md, cutover)."
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "owner/name of the GitHub repository whose Actions may assume the deploy role."
  type        = string
  default     = "aallbrig/mechapilot"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be owner/name."
  }
}

variable "github_environment" {
  description = "GitHub Actions environment whose jobs may assume the deploy role."
  type        = string
  default     = "production"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.github_environment))
    error_message = "github_environment must be a plain environment name (no wildcards)."
  }
}

variable "waf_rate_limit" {
  description = "Requests per client IP per 5 minutes before the WAF blocks that IP."
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100
    error_message = "waf_rate_limit must be at least 100 (the WAFv2 minimum)."
  }
}
