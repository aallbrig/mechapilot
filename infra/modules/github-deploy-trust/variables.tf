variable "oidc_provider_arn" {
  description = "ARN of the account's existing GitHub Actions OIDC provider."
  type        = string
}

variable "github_owner" {
  description = "Repository owner login."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_owner))
    error_message = "github_owner must be a GitHub login (letters, digits, hyphens)."
  }
}

variable "github_owner_id" {
  description = "Numeric ID of the repository owner, as it appears in immutable OIDC subjects (supplied in an untracked tfvars file, never committed)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_owner_id))
    error_message = "github_owner_id must be a positive integer."
  }
}

variable "github_repository" {
  description = "Repository name (without the owner)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be a plain repository name."
  }
}

variable "github_repository_id" {
  description = "Numeric ID of the repository, as it appears in immutable OIDC subjects (supplied in an untracked tfvars file, never committed)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repository_id))
    error_message = "github_repository_id must be a positive integer."
  }
}

variable "github_environment" {
  description = "Actions environment the job must run in."
  type        = string
  default     = "production"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.github_environment))
    error_message = "github_environment must be a plain name (no wildcards or separators)."
  }
}
