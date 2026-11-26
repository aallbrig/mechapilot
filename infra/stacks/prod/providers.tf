# Everything lives in us-east-1: CloudFront only takes ACM certificates and
# CLOUDFRONT-scope WAF ACLs from there, and its log delivery is set up there.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "mechapilot"
      ManagedBy = "opentofu"
      Stack     = "prod"
    }
  }
}
