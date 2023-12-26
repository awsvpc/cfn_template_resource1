SSM Automation Document deployed to management account to execute SSM Run Command Document within each managed location (account + region pair).

![SSM-Automation-RunCommand](https://user-images.githubusercontent.com/5932099/93779059-2c299e00-fbec-11ea-9d93-0e2c689215fe.png)

1. Configure Automation multi-account IAM roles: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation-multiple-accounts-and-regions.html
   - `AWS-SystemsManager-AutomationAdministrationRole` should be deployed to _management_ account
   - `AWS-SystemsManager-AutomationExecutionRole` should be deployed to all _managed_ accounts
1. Deploy Automation document via Cfn Stack to _management_ account
1. Deploy Command document via Cfn StackSet to all _managed_ accounts + regions
1. Execute SSM automation in management account to run command document against all matched target instances in all _managed_ accounts + regions:
  ```shell
  aws ssm start-automation-execution \
    --region us-east-1 \
    --document-name "MyAutomation" \
    --document-version "\$LATEST" \
    --parameters '{"AutomationAssumeRole":["arn:aws:iam::<management-acct>:role/AWS-SystemsManager-AutomationAdministrationRole"]}' \
    --target-locations '[{"Accounts":["ou-ab12-abcd1234"],
                          "Regions":["us-east-1","us-west-2"],
                          "ExecutionRoleName":"AWS-SystemsManager-AutomationExecutionRole",
                          "TargetLocationMaxErrors":"1",
                          "TargetLocationMaxConcurrency":"5"},
                         {"Accounts":["ou-cd34-cdef3456"],
                          "Regions":["us-east-1","us-west-2"],
                          "ExecutionRoleName":"AWS-SystemsManager-AutomationExecutionRole",
                          "TargetLocationMaxErrors":"1",
                          "TargetLocationMaxConcurrency":"5"}]'
  ```

<hr/>

The Command Document could be expanded to perform different tasks on an instance using different actions ("plugins"): https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html

- [Download a file from S3 using `aws:downloadContent`](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-downloadContent)
- [Install / update a package using Distributor and `aws:configurePackage`](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-configurepackage)
- [Apply a Chef Recipe or Ansible Playbook via `aws:runDocument` and the AWS-provided documents `AWS-ApplyChefRecipes` / `AWS-ApplyAnsiblePlaybooks`](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-rundocument)