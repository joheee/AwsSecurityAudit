# Read-only security audit role.
#
# Permissions: AWS managed SecurityAudit and ViewOnlyAccess, plus the extra
# read-only actions Prowler needs (below). No write actions. Keep it that way.

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AssumeWithMfa"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.trusted_principal_arn]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }

    # Only added when an external ID is given (client accounts).
    dynamic "condition" {
      for_each = var.external_id == null ? [] : [var.external_id]
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [condition.value]
      }
    }
  }
}

resource "aws_iam_role" "audit" {
  name                 = var.role_name
  description          = "Read-only role for the AWS security audit (Prowler, Checkov). Assumed with MFA."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = aws_iam_role.audit.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "view_only" {
  role       = aws_iam_role.audit.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# Prowler's additions policy: read-only actions that SecurityAudit and
# ViewOnlyAccess do not cover. Based on Prowler's
# permissions/prowler-additions-policy.json. securityhub:BatchImportFindings is
# left out on purpose because it is a write action and we do not send findings
# to Security Hub. Re-check against the pinned Prowler version when it changes.
data "aws_iam_policy_document" "prowler_additions" {
  statement {
    sid    = "ProwlerAdditionsReadOnly"
    effect = "Allow"
    actions = [
      "account:Get*",
      "appstream:Describe*",
      "appstream:List*",
      "backup:List*",
      "bedrock:List*",
      "bedrock:Get*",
      "cloudtrail:GetInsightSelectors",
      "codeartifact:List*",
      "codebuild:BatchGet*",
      "cognito-idp:GetUserPoolMfaConfig",
      "dlm:Get*",
      "drs:Describe*",
      "ds:Get*",
      "ds:Describe*",
      "ds:List*",
      "dynamodb:GetResourcePolicy",
      "ec2:GetEbsEncryptionByDefault",
      "ec2:GetInstanceMetadataDefaults",
      "ec2:GetSnapshotBlockPublicAccessState",
      "ecr:Describe*",
      "ecr:GetRegistryScanningConfiguration",
      "elasticfilesystem:DescribeBackupPolicy",
      "glue:GetConnections",
      "glue:GetSecurityConfiguration*",
      "glue:SearchTables",
      "lambda:GetFunction*",
      "logs:FilterLogEvents",
      "macie2:GetMacieSession",
      "macie2:GetAutomatedDiscoveryConfiguration",
      "s3:GetAccountPublicAccessBlock",
      "servicecatalog:Describe*",
      "servicecatalog:List*",
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "ssm:GetDocument",
      "ssm-incidents:List*",
      "states:ListTagsForResource",
      "support:Describe*",
      "tag:GetTagKeys",
      "wellarchitected:List*",
    ]
    # "*": these are account-wide describe/get calls and most of them do not
    # support resource-level permissions. All actions are read-only.
    resources = ["*"]
  }
}

resource "aws_iam_policy" "prowler_additions" {
  name        = "${var.role_name}-prowler-additions"
  description = "Extra read-only actions for Prowler. No write actions."
  policy      = data.aws_iam_policy_document.prowler_additions.json
}

resource "aws_iam_role_policy_attachment" "prowler_additions" {
  role       = aws_iam_role.audit.name
  policy_arn = aws_iam_policy.prowler_additions.arn
}
