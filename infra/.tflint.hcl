# tflint for every module and stack under infra/ (run by scripts/infra lint).
# The AWS ruleset binary is pinned and checksummed by mise (.mise.toml, mise.lock)
# and found through TFLINT_PLUGIN_DIR, so tflint never downloads plugins.
config {
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}

plugin "aws" {
  enabled = true
}
