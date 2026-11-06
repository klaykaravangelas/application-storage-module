# Non-production example

This root configuration consumes the local `application_storage` module. All
configuration values come from a local `.tfvars` file. The configuration below
selects `orders` in `dev`, enabled versioning, 30-day noncurrent-version retention,
and an owner tag. It creates a KMS key and uses it for SSE-KMS encryption. Access
logging is off until a destination is supplied. Module outputs are forwarded by
the root configuration.

## Configure the example

Create or edit `examples/non-production/terraform.tfvars` with your values:

```hcl
aws_region  = "us-west-2"
application = "orders"
environment = "dev"
name_suffix = "your-unique-suffix"

tags = {
  Owner = "application-team"
}

versioning_status                  = "Enabled"
noncurrent_version_expiration_days = 30
create_kms_key                     = true
kms_key_arn                        = null
access_logging                     = null
```

Edit `terraform.tfvars` to choose your application, environment, unique suffix,
Region, tags, versioning, retention, and optional KMS/logging settings. Terraform
automatically loads this file from the example directory. The local `.tfvars`
file is ignored by Git. AWS credentials stay in your normal profile or environment.

`variables.tf` declares the input types and defaults. `main.tf` passes the values
to the child module. `providers.tf` pins Terraform to `1.16.1`, pins the AWS
provider to `6.72.0`, and configures the AWS Region. The Terraform pin matches CI
and requires that CLI version to be installed; it does not install Terraform.
Initialization generates a local lock file with provider package checksums.
The example's lock file is not ignored by Git. The reusable child module
declares minimum versions so other consumers can choose their supported versions.

## Validate without AWS credentials

Run from the repository root:

```sh
terraform fmt -check -recursive
terraform -chdir=examples/non-production init -backend=false
terraform -chdir=examples/non-production validate
terraform -chdir=examples/non-production test
```

The test runs a plan with a mocked AWS provider and checks the bucket name and
generated key ARN from the child module. Its inputs are declared in the test
itself, so neither a local `.tfvars` file nor AWS credentials are needed. It creates
no AWS resources.
Initialization needs access to provider packages or a configured local cache/mirror.

This command runs the example's tests. The [module documentation](../../README.md)
has the commands for its separate suite. CI runs both suites; any failure makes
the overall workflow fail.

## Generate a plan with the real provider

**A normal `terraform plan` requires valid AWS credentials.** Configure them through
your normal AWS profile or environment, and create the local `.tfvars` file above.
For example, after authenticating an existing development profile:

```sh
export AWS_PROFILE=your-development-profile
terraform -chdir=examples/non-production init -backend=false
terraform -chdir=examples/non-production plan
```

Choose a suffix that makes the complete name available. A plan can use AWS APIs
but creates no resources. Reviewers do not need to run `terraform apply`.
Setting `AWS_PROFILE` selects an existing profile; it does not authenticate it.
`init -backend=false` disables backend initialization, not AWS provider authentication.
Without AWS credentials, use the mocked tests above for plan-time review.
The example uses local state if subsequently applied; production state management
is outside this example's scope.

## KMS and optional logging

The example configuration creates a KMS key for application data using these
values in your local `terraform.tfvars`:

```hcl
create_kms_key = true
kms_key_arn    = null
```

The generated key uses automatic rotation, a 30-day deletion window, and the
bucket's tags. The `kms_key_arn` output exposes it for application IAM policies.

To use SSE-S3 instead, set `create_kms_key = false` and keep `kms_key_arn = null`.
The reusable module still uses SSE-S3 by default; this example opts into key creation.

To reuse an existing key instead, set `create_kms_key = false` and supply its
ARN. Logging remains optional and requires an existing destination:

```hcl
create_kms_key = false
kms_key_arn    = "arn:aws:kms:us-west-2:111122223333:key/12345678-1234-1234-1234-123456789012"

access_logging = {
  target_bucket = "central-logs-example"
  target_prefix = "orders/dev/"
}
```

Replace the sample values. Existing keys must be in the selected Region.
Application principals need KMS permissions for either a created or existing key.
The log destination must be in the same account and
Region as the source, use SSE-S3, and allow S3 log delivery. Match its delivery
policy to the actual source bucket name, account, and prefix.
See the [module documentation](../../README.md) for the permission examples and
tradeoffs, including generated-key deletion behavior. To use a different Region,
change `aws_region` in your local file.
