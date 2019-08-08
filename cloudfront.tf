resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "${var.site_name}${var.domain} Created by Terraform"
}

data "aws_iam_policy_document" "access-logs-write" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.access_logs_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.access_logs_bucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs_bucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket" "access_logs_bucket" {
  bucket = "${var.site_name}${var.domain}-access-logs"
  acl    = "private"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.main.id}.s3.amazonaws.com"
    origin_id   = "S3-${aws_s3_bucket.main.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  comment             = "Created by terraform, dont edit manually!!"
  default_root_object = "index.html"

  aliases = ["${var.site_name}${var.domain}"]

  logging_config {
    bucket = "${aws_s3_bucket.access_logs_bucket.id}.s3.amazonaws.com"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.main.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    iam_certificate_id       = var.ssl_cert
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  custom_error_response {
    error_code            = "404"
    error_caching_min_ttl = "0"
    response_code         = var.error_response_code
    response_page_path    = var.error_response_pagepath
  }

  web_acl_id = var.web_acl_id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.s3_distribution.id
}
