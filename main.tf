
provider "vault" {
  address = var.vault_addr
  token = var.vault_token
}

resource "vault_aws_secret_backend" "aws" {
  access_key                = var.root_access_key
  secret_key                = var.root_secret_key
  path                      = "aws"
  default_lease_ttl_seconds = "120"
  max_lease_ttl_seconds     = "240"
}

resource "vault_aws_secret_backend_role" "admin" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "dynamoDB"
  credential_type = "iam_user"
  policy_document = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:*", "ec2:*","dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "vault_mount" "transform" {
  path = "transform"
  type = "transform"
}

resource "vault_transform_transformation" "ccn-fpe" {
  path          = vault_mount.transform.path
  name          = "ccn-fpe"
  type          = "fpe"
  template      = "builtin/creditcardnumber"
  tweak_source  = "internal"
  allowed_roles = ["payments"]
}
resource "vault_transform_role" "payments" {
  path            = vault_transform_transformation.ccn-fpe.path
  name            = "payments"
  transformations = ["ccn-fpe"]
}

output "transform" {
  value = vault_transform_transformation.ccn-fpe.path
  
}
