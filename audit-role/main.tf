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
# ViewOnlyAccess do not cover. Copied from Prowler 5.49.0
# (permissions/prowler-additions-policy.json). securityhub:BatchImportFindings
# is left out on purpose: it is a write action and we do not send findings to
# Security Hub. Re-check against the upstream file when the pinned Prowler
# version changes.
data "aws_iam_policy_document" "prowler_additions" {
  statement {
    sid    = "ProwlerAdditionsReadOnly"
    effect = "Allow"
    actions = [
      "account:Get*",
      "amplify:ListApps",
      "amplify:ListBranches",
      "appstream:Describe*",
      "appstream:List*",
      "backup:List*",
      "backup:Get*",
      "bedrock-agentcore:GetAgentRuntime",
      "bedrock-agentcore:GetBrowser",
      "bedrock-agentcore:GetCodeInterpreter",
      "bedrock-agentcore:GetGateway",
      "bedrock-agentcore:GetGatewayTarget",
      "bedrock-agentcore:GetMemory",
      "bedrock-agentcore:GetTokenVault",
      "bedrock-agentcore:ListAgentRuntimes",
      "bedrock-agentcore:ListBrowsers",
      "bedrock-agentcore:ListCodeInterpreters",
      "bedrock-agentcore:ListGatewayTargets",
      "bedrock-agentcore:ListGateways",
      "bedrock-agentcore:ListMemories",
      "bedrock-agentcore:ListTagsForResource",
      "bedrock:List*",
      "bedrock:Get*",
      "cloudtrail:GetInsightSelectors",
      "codeartifact:List*",
      "codebuild:BatchGet*",
      "codebuild:ListReportGroups",
      "cognito-idp:GetUserPoolMfaConfig",
      "datapipeline:DescribePipelines",
      "datapipeline:GetPipelineDefinition",
      "datapipeline:ListPipelines",
      "dlm:Get*",
      "drs:Describe*",
      "ds:Get*",
      "ds:Describe*",
      "ds:List*",
      "dynamodb:GetResourcePolicy",
      "ec2:GetEbsEncryptionByDefault",
      "ec2:GetSnapshotBlockPublicAccessState",
      "ec2:GetInstanceMetadataDefaults",
      "ecr:Describe*",
      "ecr:GetRegistryScanningConfiguration",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "elasticfilesystem:DescribeBackupPolicy",
      "glue:GetConnections",
      "glue:GetSecurityConfiguration*",
      "glue:SearchTables",
      "glue:GetMLTransforms",
      "inspector2:BatchGetFindingDetails",
      "inspector2:SearchVulnerabilities",
      "lambda:GetFunction*",
      "lambda:GetLayerVersion",
      "logs:FilterLogEvents",
      "lightsail:GetRelationalDatabases",
      "macie2:GetMacieSession",
      "macie2:GetAutomatedDiscoveryConfiguration",
      "oam:GetSinkPolicy",
      "oam:ListTagsForResource",
      "rolesanywhere:ListProfiles",
      "rolesanywhere:ListTagsForResource",
      "rolesanywhere:ListTrustAnchors",
      "s3:GetAccountPublicAccessBlock",
      "s3:GetObjectAcl",
      "s3:ListBucket",
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "securityhub:GetFindings",
      "servicecatalog:Describe*",
      "servicecatalog:List*",
      "ssm:GetDocument",
      "ssm-incidents:List*",
      "states:ListTagsForResource",
      "support:Describe*",
      "tag:GetTagKeys",
      "wellarchitected:List*",
    ]
    # "*": these are account-wide describe/get calls and most of them do not
    # support resource-level permissions. All actions are read-only. Note that
    # ecr:BatchGetImage, ecr:GetDownloadUrlForLayer and lambda:GetLayerVersion
    # can download image and layer content, not only metadata.
    resources = ["*"]
  }

  statement {
    sid     = "ProwlerAdditionsApiGatewayRead"
    effect  = "Allow"
    actions = ["apigateway:GET"]
    # Scoped to API Gateway REST, HTTP and domain name resources, as upstream.
    resources = [
      "arn:*:apigateway:*::/restapis/*",
      "arn:*:apigateway:*::/apis/*",
      "arn:*:apigateway:*::/domainnames",
      "arn:*:apigateway:*::/domainnames/*",
    ]
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
