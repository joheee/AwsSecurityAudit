variable "region" {
  description = "Region for the provider. The org SCP allows ap-southeast-2 only."
  type        = string
  default     = "ap-southeast-2"
}

variable "role_name" {
  description = "Name of the read-only audit role."
  type        = string
  default     = "security-audit"
}

variable "trusted_principal_arn" {
  description = "ARN of the IAM user or role allowed to assume the audit role (with MFA). No default on purpose: it contains an account ID."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(user|role)/.+$", var.trusted_principal_arn))
    error_message = "Must be an IAM user or role ARN, for example arn:aws:iam::123456789012:user/name."
  }
}

variable "external_id" {
  description = "Optional sts:ExternalId required to assume the role. Set it for client accounts where the auditor assumes the role from another account."
  type        = string
  default     = null
  sensitive   = true
}

variable "max_session_duration" {
  description = "Maximum session length in seconds (3600 to 43200). One hour is enough for a scan; raise it for slow accounts."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200."
  }
}
