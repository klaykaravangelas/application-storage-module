# application-storage-module

A reusable Terraform module for application S3 buckets with consistent naming and
tags, SSE-S3 or optional SSE-KMS encryption, public access blocking, HTTPS
enforcement, configurable versioning, optional expiration of noncurrent object
versions, and optional server access logging.

## Requirements

- Terraform >= 1.11.0 for the reusable module; exactly 1.16.1 for the example and CI.
- HashiCorp AWS provider >= 6.0.0.

The consuming root module configures the AWS provider, credentials, Region, and
state backend. The example groups Terraform's exact `1.16.1` requirement, the
AWS provider's exact `6.72.0` requirement, and Region configuration in `providers.tf`.
The reusable child module declares minimum versions so consumers can choose their
supported Terraform and provider releases.

Terraform 1.11 is required so the test suite can provide a mocked ARN during
planning. Checks have passed with Terraform 1.16.1 and AWS provider
6.72.0.

## Usage

Declare inputs in the calling root and pass their values to the module:

```hcl
provider "aws" {
  region = var.aws_region
}

module "application_storage" {
  source = "./modules/application_storage"

  application = var.application
  environment = var.environment
  name_suffix = var.name_suffix

  versioning_status                  = var.versioning_status
  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
  create_kms_key                    = var.create_kms_key
  kms_key_arn                        = var.kms_key_arn
  access_logging                     = var.access_logging

  tags = var.tags
}
```

The caller must choose an available bucket name. The module does not check global
availability or manage application IAM permissions.

The [non-production example](examples/non-production/README.md) provides a runnable
root configuration with variable declarations, documented local `.tfvars` values,
optional KMS and logging inputs, outputs, and its own mocked plan test.
Its documented configuration creates a KMS key and uses it for SSE-KMS encryption.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `application` | string | Required | Application identifier used in naming and tags. |
| `environment` | string | Required | Environment identifier used in naming and tags. |
| `name_suffix` | string | Required | Caller-chosen suffix to help avoid name collisions. |
| `tags` | map(string) | `{}` | Additional bucket tags. Standard module tags take precedence on conflicts. |
| `create_kms_key` | bool | `false` | Create a KMS key for the application bucket; requires `kms_key_arn = null`. |
| `kms_key_arn` | string | `null` | Existing KMS key ARN; `null` uses SSE-S3 unless `create_kms_key` is true. |
| `versioning_status` | string | `"Enabled"` | Bucket versioning status: `Enabled` or `Suspended`. |
| `noncurrent_version_expiration_days` | number | `null` | Positive whole number of days before noncurrent versions expire; `null` leaves expiration off. |
| `access_logging` | object | `null` | Existing `target_bucket` and optional `target_prefix` (default `access-logs/`); `null` leaves logging off. |

Names follow `<application>-<environment>-<name_suffix>`. Each component accepts
lowercase letters, digits, and hyphens and must start and end with a letter or digit.
Variable validation checks the individual components. The complete name remains
subject to S3's length and reserved-name restrictions. Periods are excluded to keep
the convention simple.
Changing a naming input changes the bucket name and requires replacement.
See [AWS bucket naming rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html).

Standard tags are `Application`, `Environment`, and `ManagedBy = "Terraform"`.
The module's values override conflicting entries in `tags`. Provider default tags
can add other tags; explicitly configured bucket tags override matching provider
default tags.

## Outputs

| Name | Description |
| --- | --- |
| `bucket_name` | Name of the application bucket. |
| `bucket_arn` | Bucket ARN for consumer IAM policies. |
| `bucket_regional_domain_name` | Regional domain name for the bucket. |
| `kms_key_arn` | Created or supplied KMS key ARN, or `null` for SSE-S3. |

Access an output through the module call, for example
`module.application_storage.bucket_arn`. Outputs identify the bucket and do not
grant permissions.

## Security decisions

- Default to SSE-S3 (`AES256`). Supply `kms_key_arn` to reuse a key, or set
  `create_kms_key = true` to create one. Either KMS choice selects SSE-KMS (`aws:kms`).
  The two KMS options are mutually exclusive.
- Enable all four bucket-level public access block settings. These controls have
  no input allowing a caller to disable them.
- Deny insecure transport for bucket and object operations. Exclude direct AWS
  service principals from the deny, following AWS guidance on redacted network
  context in service-to-service calls. The policy enforces HTTPS; it does not
  grant access or specify a minimum TLS protocol version.
- Keep `force_destroy = false`. Terraform will not automatically empty the bucket
  to destroy it; an empty bucket can still be destroyed.

See [AWS transport-policy guidance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html#example-bucket-policies-tls-version).

To use KMS for application data, add this input to the module call:

```hcl
kms_key_arn = "arn:aws:kms:us-west-2:111122223333:key/12345678-1234-1234-1234-123456789012"
```

Alternatively, create a key in the module:

```hcl
create_kms_key = true
kms_key_arn    = null
```

The generated key is a symmetric encryption key in the bucket's Region, with
automatic rotation, a 30-day deletion window, and the same tags as the bucket.
It uses AWS's default programmatic key policy, which enables the owning account
to delegate access through IAM policies. The `kms_key_arn` output identifies the
selected key for consumer policies. See [AWS default key policy](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html).

Existing keys must also be symmetric encryption keys in the bucket's Region.
Application writers need `kms:GenerateDataKey`; readers need `kms:Decrypt`;
multipart uploads need both, in addition to S3 permissions. The caller manages
these application permissions for either key choice. SSE-KMS adds KMS charges.

The module owns generated keys. Setting `create_kms_key` back to `false`, or
destroying the key resource, schedules its deletion with a 30-day waiting period.
Pending-deletion keys cannot be used for cryptographic operations; permanent key
deletion makes data encrypted with that key unrecoverable.
See [AWS key deletion behavior](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html).

This changes default encryption for new uploads; existing objects are not
re-encrypted, and the module does not add a policy requiring every upload to use
this key. The separate access-log destination still uses SSE-S3.
See [AWS KMS encryption guidance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html).

## Versioning and retention

Versioning is enabled by default. Set `versioning_status = "Suspended"` to suspend
it. Once enabled, S3 versioning cannot return to an unversioned state, and suspension
does not remove existing versions. Each stored version contributes to storage costs.
See [AWS versioning guidance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html).

Noncurrent-version expiration is off by default. Supplying a retention period creates
one lifecycle rule covering all objects. For example, `30` makes noncurrent versions
eligible for permanent deletion after 30 days as noncurrent versions. Current object
versions are unaffected. The rule can remain enabled while versioning is suspended
to expire older versions. The lifecycle configuration depends on the bucket's
versioning configuration so Terraform applies them in that order.

The usage example chooses 30 days to demonstrate the feature; callers should select
a period appropriate for their data. See [AWS noncurrent-version expiration](https://docs.aws.amazon.com/AmazonS3/latest/API/API_NoncurrentVersionExpiration.html).

## Access logging

Logging is off by default. Add this input to the module call to enable it:

```hcl
access_logging = {
  target_bucket = "central-logs-example"
  target_prefix = "orders/dev/"
}
```

`target_bucket` is the existing bucket's name. Omitting `target_prefix` uses
`access-logs/`. A prefix groups log objects by their keys; it does not create a
directory.

The caller prepares a separate destination bucket in the same AWS account and
Region. It must use SSE-S3 encryption, have Object Lock and Requester Pays off,
and permit log delivery. Leave logging off on the destination to avoid recursive
logging. These are destination prerequisites, not resources managed by this module.

For an application bucket named `orders-dev-example`, this example destination
policy permits delivery under `orders/dev/`. Replace the bucket names, source
account ID, and ARN partition as appropriate, and merge the statement into the
destination's existing policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowApplicationAccessLogs",
    "Effect": "Allow",
    "Principal": {"Service": "logging.s3.amazonaws.com"},
    "Action": "s3:PutObject",
    "Resource": "arn:aws:s3:::central-logs-example/orders/dev/*",
    "Condition": {
      "ArnLike": {"aws:SourceArn": "arn:aws:s3:::orders-dev-example"},
      "StringEquals": {"aws:SourceAccount": "111122223333"}
    }
  }]
}
```

The policy must match the configured prefix and source bucket. See
[AWS logging setup and permissions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html).
Mocked tests verify the source configuration; they do not verify destination
permissions or actual log delivery. Log objects incur storage costs.

## Validation and tests

Run from the repository root:

```sh
terraform fmt -check -recursive
terraform -chdir=modules/application_storage init -backend=false
terraform -chdir=modules/application_storage validate
terraform -chdir=modules/application_storage test
terraform -chdir=examples/non-production init -backend=false
terraform -chdir=examples/non-production validate
terraform -chdir=examples/non-production test
```

Initialization downloads provider packages, or uses a configured local cache or
mirror. Each directory generates its own provider lock file during initialization.
Only the standalone child module's lock file is ignored by Git. All test runs use
a mocked AWS provider and `command = plan`; they need no AWS credentials and
create no AWS resources. Mocked plans check the module's configuration rather
than AWS authorization, name availability, or live behavior.

Ten module test runs cover the core behaviors:

- `bucket_basics`: bucket name, deletion configuration, and standard tags.
- `custom_tags_preserve_standards`: preserve additional tags and enforce standard tags.
- `secure_defaults`: SSE-S3 encryption, all four public access block settings,
  and HTTPS policy scope and conditions.
- `kms_encryption`: SSE-KMS with the caller's key ARN when supplied.
- `generated_kms_key`: create a rotated, tagged key, use it for SSE-KMS, and expose its ARN.
- `reject_conflicting_kms_options`: reject simultaneous key creation and an existing key ARN.
- `versioning_and_retention_defaults`: versioning enabled and expiration off.
- `configured_versioning_and_retention`: suspended versioning and an enabled
  noncurrent-version expiration rule that leaves current versions unaffected.
- `logging_off_by_default`: no logging configuration without a destination.
- `logging_enabled`: the configured destination and log-object prefix.

The example has one additional test, `non_production_example`, which verifies the
consuming root module, its bucket-name output, and its generated-key ARN output.
It supplies its own test inputs and needs no local `.tfvars` file. It does not automatically run the child module's
test suite; the two test commands above run both suites separately.

**Normal plan generation requires valid AWS credentials.** Create or edit the
ignored `examples/non-production/terraform.tfvars` file using the values documented
in the example README, choosing a unique suffix and any optional settings. After
authenticating an AWS profile or configuring credentials in the environment, run:

```sh
terraform -chdir=examples/non-production plan
```

This can access AWS APIs but does not create resources. No `terraform apply` is
required for review. See the [example instructions](examples/non-production/README.md)
for profile setup and optional KMS/logging settings. Without credentials, use the
mocked tests for plan-time validation. `init -backend=false` does not remove the
AWS provider's authentication requirement for a normal plan.

## CI validation

The [GitHub Actions workflow](.github/workflows/terraform.yml) runs on pushes,
pull requests, and manual dispatch. It checks formatting, initializes, validates,
and runs mocked plan tests for both the module and the non-production example
as separate matrix jobs. Failure in either
job makes the overall workflow fail, even if the other job passes. The example
test supplies its own inputs, so CI needs neither a local `.tfvars` file nor AWS
credentials.

Each job runs `terraform init` to select providers and generate a lock file for
the runner's platform. CI does not commit these generated files. The example uses
its exact AWS provider requirement of `6.72.0`; standalone module tests select the
latest available provider satisfying the module's `>= 6.0.0` requirement.

Terraform is pinned to 1.16.1 and the two Actions are pinned to verified commit
SHAs. The job has read-only repository permissions.

## Assumptions and tradeoffs

- Application IAM permissions and access log destinations are managed by the
  caller. KMS keys can be supplied by the caller or owned by this module.
- Basic naming validation keeps the interface small; complete name validity and
  availability remain subject to the AWS provider and AWS.
- Versioning favors recovery; retention is opt-in because it permanently deletes
  older versions. The example's 30-day value is illustrative.
- Encryption settings establish defaults for new uploads and do not re-encrypt
  existing objects or enforce a particular key on every upload.
- Mocked plans demonstrate module behavior without a deployment. They do not
  establish that real IAM policies, KMS permissions, and log delivery work.

## Further improvements

Additional time could cover custom bucket policy composition, import/migration
examples, and live integration tests in a dedicated AWS account.
