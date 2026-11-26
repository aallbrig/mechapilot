variable "domain_name" {
  description = "Canonical host name the site is served on, e.g. game.example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a lower-case DNS name."
  }
}

variable "redirect_domain_names" {
  description = "Extra host names (e.g. www.) that answer with a 301 to https://<domain_name>, keeping the path and query."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for d in var.redirect_domain_names : can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", d))])
    error_message = "Every redirect domain must be a lower-case DNS name."
  }
}

variable "bucket_name" {
  description = "Name of the private S3 bucket that holds the site's files."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name."
  }
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone that receives the A and AAAA alias records. Supplied at apply time, never committed."
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "hosted_zone_id must look like a Route 53 hosted zone ID."
  }
}

variable "certificate_arn" {
  description = "ARN of an issued ACM certificate in us-east-1 that covers domain_name and every redirect domain. Supplied at apply time, never committed."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:acm:us-east-1:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn))
    error_message = "certificate_arn must be an ACM certificate ARN in us-east-1 (CloudFront requires us-east-1)."
  }
}

variable "web_acl_arn" {
  description = "ARN of a CLOUDFRONT-scope WAFv2 web ACL (us-east-1) that protects the distribution. One ACL can be shared by several sites."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:wafv2:us-east-1:[0-9]{12}:global/webacl/[A-Za-z0-9_-]+/[0-9a-f-]+$", var.web_acl_arn))
    error_message = "web_acl_arn must be a CLOUDFRONT-scope (global) WAFv2 web ACL ARN."
  }
}

variable "aliases_enabled" {
  description = "Attach the host names to the distribution and create the DNS alias records. Set false to build the site alongside an older distribution that still owns the names (see infra/README.md, cutover)."
  type        = bool
  default     = true
}

variable "content_security_policy" {
  description = "Content-Security-Policy header value sent with every response."
  type        = string
  default     = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; media-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' data: blob:; worker-src 'self' blob:; manifest-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests"

  validation {
    condition     = strcontains(var.content_security_policy, "frame-ancestors 'none'")
    error_message = "The CSP must keep frame-ancestors 'none'."
  }
}

variable "hsts_max_age_seconds" {
  description = "Strict-Transport-Security max-age in seconds."
  type        = number
  default     = 63072000

  validation {
    condition     = var.hsts_max_age_seconds >= 31536000
    error_message = "HSTS max-age must be at least one year."
  }
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "price_class must be PriceClass_All, PriceClass_200 or PriceClass_100."
  }
}

variable "not_found_path" {
  description = "Object served, with status 404, for paths that do not exist."
  type        = string
  default     = "/404.html"

  validation {
    condition     = startswith(var.not_found_path, "/")
    error_message = "not_found_path must start with /."
  }
}

variable "logging_enabled" {
  description = "Deliver CloudFront access logs to a private, encrypted log bucket that expires them."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Days to keep access logs before they expire."
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 1
    error_message = "log_retention_days must be at least 1."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep overwritten or deleted site objects, so a bad upload can be rolled back."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_retention_days >= 1
    error_message = "noncurrent_version_retention_days must be at least 1."
  }
}
