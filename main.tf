
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

data "vault_aws_access_credentials" "creds" {
  backend = vault_aws_secret_backend_role.admin.backend
  role    = vault_aws_secret_backend_role.admin.name
}

data "vault_transform_encode" "test" {
    path        = vault_transform_role.payments.path
    role_name   = "payments"
    value       = var.ccn
}


provider "aws" {
  depends_on = [vault_aws_access_credentials]
  region     = var.region
  access_key = data.vault_aws_access_credentials.creds.access_key
  secret_key = data.vault_aws_access_credentials.creds.secret_key
}

resource "aws_dynamodb_table" "customers_db" {
  name           = "customers"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "customer_id"

  attribute {
    name = "customer_id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "customers_items" {
  table_name = aws_dynamodb_table.customers_db.name
  hash_key   = aws_dynamodb_table.customers_db.hash_key

  item = <<ITEM
{
  "customer_id": {"S": "1"},
  "FirstName": {"S": "Dan"},
  "Surname": {"S": "Peacock"},
  "CCN": {"S": "${data.vault_transform_encode.test.encoded_value}"}
}
ITEM
}
