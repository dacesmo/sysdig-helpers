# Sysdig Helpers
Scripts to assist on Sysdig functionalities

## [cspm-health-check-runbook.sh](./cspm-health-check-runbook.sh) 

### Description

This script can be used to determine the health of your accounts onboarded to Sysdig. By executing this script you will get a csv report that contains information about the accounts onboarded in the Sysdig Backend and their current status. If the account is not found at Sysdig, it will report the account as not found in the script output.

### Prerequisites

- Access to a Bash console to execute the script
- Have [package 'jq' installed](https://jqlang.github.io/jq/download/) in your bash terminal
- Access to a Sysdig Secure token with enough permissions to pull CSPM data [click here to learn more about Sysdig RBAC](https://docs.sysdig.com/en/docs/administration/administration-settings/user-and-team-administration/manage-custom-roles/#custom-roles-and-privileges).

### Usage

- Clone this repo.
  ```bash
  git clone git@github.com:dacesmo/sysdig-helpers.git
  ```
- ```cd``` to the repo directory
  ```bash
  cd sysdig-helpers
  ```
- Give execution permissions to the script
  ```bash
  chmod +x ./cspm-health-check-runbook.sh
  ```
- (Optional) export your token (you can also pass it at execution time)
  ```bash
  export SECURE_API_TOKEN="*****-*****-******-*****"
  ```
- Execute the script
  ```bash
  ./cspm-health-check-runbook.sh -a <single-cloud-account>
  ## You can also pass the token as a variable
  SECURE_API_TOKEN="*****-*****-******-*****" ./cspm-health-check-runbook.sh -a <single-cloud-account>
  ## Or use a parameter to define the token
  ./cspm-health-check-runbook.sh -a <single-cloud-account> -t "*****-*****-******-*****"
  ```
  Additionally you can use the following flags:
  ```bash
  -a <single-cloud-account> return status of a single account
  -A return status of ALL the accounts in Sysdig
  -l <account,account...> return the status of a list of accounts (comma separated)
  -t <secure-api-token> Set the SECURE_API_TOKEN required variable
  -r <region> Your Sysdig Secure Region (us1, us2, us4, eu1, au1), default: eu1
  -o <outputfile> output file name, defaults: accounts_results.<data>.csv
  -i insecure connection, won't check certificates (behin proxy, etc), default: false USE AT YOUR OWN RISK
  -h print this help
  ```

## Contribute
Please contribute to this repo using Pull Requests, issues to be reported via GitHub issues.
