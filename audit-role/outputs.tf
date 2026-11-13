output "role_arn" {
  description = "ARN of the audit role. Use it with aws sts assume-role (and --serial-number / --token-code for MFA)."
  value       = aws_iam_role.audit.arn
}

output "role_name" {
  description = "Name of the audit role."
  value       = aws_iam_role.audit.name
}
