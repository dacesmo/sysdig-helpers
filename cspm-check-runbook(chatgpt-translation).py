#!/usr/bin/env python3

import sys
import os
import datetime
import requests
import json

# Check for SECURE_API_TOKEN, else terminate with error code 1
SECURE_API_TOKEN = os.getenv("SECURE_API_TOKEN")
if not SECURE_API_TOKEN:
    print("The API token must be set before running the script by exporting the var or run it as an env var before the script. I.e.: 'SECURE_API_TOKEN=<your_sysdig_secure_api_token> {}'".format(sys.argv[0]))
    sys.exit(1)

OUTFILE = "accounts_results.{}.csv".format(datetime.datetime.now().strftime("%d-%m.%H%M%S"))
with open(OUTFILE, "w") as f:
    f.write("Account ID;Last Scan ID;Last Scan Status;Start Date;End Date;Logs;Role Validation\n")

args = iter(sys.argv[1:])
for arg in args:
    if arg == "-t" or arg == "--secure-api-token":
        SECURE_API_TOKEN = next(args)
    elif arg == "-a" or arg == "--account-id":
        ACCOUNT_ID = next(args)
    elif arg == "-A" or arg == "--all-accounts":
        ALL_ACCOUNTS = True
    else:
        print("Invalid option")
        sys.exit(13)

if not hasattr(ACCOUNT_ID, 'ALL_ACCOUNTS'):
    print("You must specify an account to look for using the -a flag or --account option, alternatively you can query all the accounts with flag -A or option --all-accounts")
    sys.exit(1)

def check_account(account):
    response = requests.get("https://eu1.app.sysdig.com/api/cloud/v2/accountIDs", headers={"Authorization": "Bearer {}".format(SECURE_API_TOKEN), "Content-Type": "application/json"})
    if account not in response.json():
        print("ERROR: Account \"{}\" not found".format(account))
        sys.exit(1)

    tasks_response = requests.get("https://eu1.app.sysdig.com/api/cspm/v1/tasks?filter=parameters+contains+%27account%3A+{}%27".format(account), headers={"Authorization": "Bearer {}".format(SECURE_API_TOKEN), "Content-Type": "application/json"})
    last_task = tasks_response.json()[0][0]

    task_status = last_task["status"]
    print("Account \"{}\" Last Scan Status: \"{}\".".format(account, task_status))

    if task_status == "Failed":
        task_id = last_task["id"]
        report_line = "{};".format(account)

        task_response = requests.get("https://eu1.app.sysdig.com/api/cspm/v1/tasks/{}".format(task_id), headers={"Authorization": "Bearer {}".format(SECURE_API_TOKEN), "Content-Type": "application/json"})
        task_data = task_response.json()["data"]
        report_line += "{};{};{};{};".format(task_data["id"], task_data["status"], task_data["startDate"], task_data["endDate"])
        
        logs = ";".join([log["details"] for log in task_data["logs"]])
        report_line += "{};".format(logs)

        role_validation_response = requests.get("https://eu1.app.sysdig.com/api/cloud/v2/accounts/{}/validateRole".format(account), headers={"Authorization": "Bearer {}".format(SECURE_API_TOKEN), "Content-Type": "application/json"})
        report_line += role_validation_response.text

        with open(OUTFILE, "a") as f:
            f.write(report_line + "\n")
    else:
        print("No issues detected with account {}".format(account))
        with open(OUTFILE, "a") as f:
            f.write("{};{};{};{};;\n".format(account, last_task["id"], last_task["status"], last_task["startDate"], last_task["endDate"]))

if hasattr(sys.argv, 'ALL_ACCOUNTS'):
    response = requests.get("https://eu1.app.sysdig.com/api/cloud/v2/accountIDs", headers={"Authorization": "Bearer {}".format(SECURE_API_TOKEN), "Content-Type": "application/json"})
    for account_id in response.json():
        print("All Accounts mode enabled")
        check_account(account_id)
else:
    check_account(ACCOUNT_ID)

print("Results recorded in file {}".format(OUTFILE))
sys.exit(0)
