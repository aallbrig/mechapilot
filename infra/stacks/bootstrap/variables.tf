variable "region" {
  description = "Region of the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique name of the state bucket (supplied in an untracked tfvars file, never committed)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep superseded state versions for recovery."
  type        = number
  default     = 365

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Keep superseded state for at least 30 days."
  }
}
