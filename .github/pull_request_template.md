## What changed

<!-- One or two sentences. What does this PR do and why. -->

## Plan review

- [ ] I read the `terraform plan` comment on this PR for every environment
- [ ] No unexpected `destroy` or `replace` in the plan
- [ ] Cost impact is understood (check the Infracost comment if present)

## Checks

- [ ] `terraform fmt -recursive` is clean
- [ ] `tflint --recursive` is clean
- [ ] New or changed module behaviour is covered by a `.tftest.hcl` assertion
- [ ] New checkov findings are either fixed or suppressed inline with a reason
- [ ] No secrets, account ids, or `.tfvars` files added

## Rollback

<!-- How do we undo this if it goes wrong? -->
