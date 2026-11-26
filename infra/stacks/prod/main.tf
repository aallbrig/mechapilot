# Production: the Marketing Site (apex; www redirects to it), the Game Site
# (game.), a shared WAF and the GitHub Actions deploy role.
# Applied by a human only (infra/README.md).

# ---- Adopted, not recreated: the registrar's hosted zone and the wildcard certificate ----

import {
  to = aws_route53_zone.main
  id = var.hosted_zone_id
}

import {
  to = aws_acm_certificate.main
  id = var.certificate_arn
}

resource "aws_route53_zone" "main" {
  name    = var.domain
  comment = var.hosted_zone_comment

  lifecycle {
    prevent_destroy = true
  }
}

# Its DNS-validation CNAME stays in the zone (not managed here), so ACM keeps renewing it.
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
  }
}

# ---- Shared WAF in front of both distributions ----

resource "aws_wafv2_web_acl" "sites" {
  name        = "mechafighter-sites"
  description = "Managed protections and a per-IP rate limit for the static sites"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-known-bad-inputs"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "mechafighter-sites"
    sampled_requests_enabled   = true
  }
}

# ---- The two sites ----

module "marketing_site" {
  source = "../../modules/static-site"

  domain_name           = var.domain
  redirect_domain_names = ["www.${var.domain}"]
  bucket_name           = var.marketing_bucket_name
  hosted_zone_id        = aws_route53_zone.main.zone_id
  certificate_arn       = aws_acm_certificate.main.arn
  web_acl_arn           = aws_wafv2_web_acl.sites.arn
  aliases_enabled       = var.marketing_aliases_enabled
}

module "game_site" {
  source = "../../modules/static-site"

  domain_name     = "game.${var.domain}"
  bucket_name     = var.game_bucket_name
  hosted_zone_id  = aws_route53_zone.main.zone_id
  certificate_arn = aws_acm_certificate.main.arn
  web_acl_arn     = aws_wafv2_web_acl.sites.arn
  # The Godot web build (single-threaded) needs wasm compilation plus the
  # exported HTML shell's inline <script> and <style>; nothing else is relaxed.
  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' data: blob:; worker-src 'self' blob:; manifest-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests"
}
