output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.ui.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (used for cache invalidations)"
  value       = aws_cloudfront_distribution.ui.id
}

output "cloudfront_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.ui.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting UI assets"
  value       = aws_s3_bucket.ui.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.ui.arn
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.ui.bucket_regional_domain_name
}
