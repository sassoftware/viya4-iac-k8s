# For more information on configuring TFlint; see https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md

# For more information on plugins see https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/plugins.md

# For more information on TFlint Ruleset for Terraform; see https://github.com/terraform-linters/tflint-ruleset-terraform/blob/v0.3.0/docs/rules/README.md

# For more information on TFlint Ruleset for GCP, see https://github.com/terraform-linters/tflint-ruleset-google/blob/master/README.md

config {
  # Enables module inspection.
  call_module_type = "all"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# We specify the versions and providers in the top level versions.tf.
# This stops it from throwing a warning when scanning our modules
# in ./modules
rule "terraform_required_version" {
  enabled = false
}
rule "terraform_required_providers" {
  enabled = false
}
