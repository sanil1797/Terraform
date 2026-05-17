# ============================================================
#  outputs.tf
#  After "terraform apply" finishes, these values are
#  printed in the terminal so you know what was created.
#
#  You'll copy these URLs into index.html to connect the
#  website to the backend API.
# ============================================================


# The public URL of your website (from S3 static hosting)
output "website_url" {
  description = "Open this URL in your browser to see the website"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

# The full URL to call when a user subscribes
output "subscribe_endpoint" {
  description = "Paste this into index.html as SUBSCRIBE_ENDPOINT"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/subscribe"
}

# The full URL to call when a user creates an event
output "create_event_endpoint" {
  description = "Paste this into index.html as CREATE_EVENT_ENDPOINT"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/create-event"
}

# The SNS topic ARN (just for reference / debugging)
output "sns_topic_arn" {
  description = "The SNS topic ARN (already wired to Lambda automatically)"
  value       = aws_sns_topic.event_announcements.arn
}
