#! /bin/bash

# Check for SECURE_API_TOKEN, else terminate with error code 1
[[ -z "$SECURE_API_TOKEN" ]] && echo "The API token must be set before running the script by exporting the var or run it as an env var before the script. I.e.:  'SECURE_API_TOKEN=<your_sysdig_secure_api_token> ${0}'" && exit 1

OUTFILE="accounts_results.$(date +"%d-%m.%H%M%S").csv"
echo "Account ID;Last Scan ID;Last Scan Status;Start Date;End Date;Logs;Role Validation" > $OUTFILE

while test $# -gt 0; do
  case "$1" in
    -t|--secure-api-token)
      shift
      SECURE_API_TOKEN=$1
      shift
      ;;
    -a|--account-id)
      shift
      ACCOUNT_ID=$1
      shift
      ;;
    -A|--all-accounts)
      shift
      ALL_ACCOUNTS=true;
      shift
      ;;
    # -a|--api-endpoint)
    #   shift
    #   SYSDIG_API_ENDPOINT=$1
    #   shift
    #   ;;
    *)
      echo "Invalid option" # . Check help (-h | --help) for additional information. Exiting ..."
      exit 13
      ;;
  esac
done

( [[ -z "$ACCOUNT_ID" ]] && [[ -z "$ALL_ACCOUNTS" ]] ) && echo "You must specify an account to look for using the -a flag or --account option, alternatively you can query all the accounts with flag -A or option --all-accounts" && exit 1

function checkAccount(){
    ACCOUNT=$1
    curl -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cloud/v2/accountIDs" |  jq | grep "\"$ACCOUNT\"" > /dev/null

    [[ $? -ne 0 ]] && echo "ERROR: Account \"$ACCOUNT\" not found" && exit 1

    LAST_TASK=$(curl -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cspm/v1/tasks?filter=parameters+contains+%27account%3A+${ACCOUNT}%27" | jq 'first(.[])|first(.[])')

    TASK_STATUS=$(echo "$LAST_TASK" | jq -r '.status')
    echo "Account \"$ACCOUNT\" Last Scan Status: \"$TASK_STATUS\"."
    if [[ $"$TASK_STATUS" == "Failed" ]] 
    then
        echo "Gathering additional information."
        TASK_ID=$(echo "$LAST_TASK" | jq -r '.id')
        REPORT_LINE="${ACCOUNT};"
        REPORT_LINE=${REPORT_LINE}$(curl -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cspm/v1/tasks/$TASK_ID" | jq -r '.data.id + ";" + .data.status + ";" + .data.startDate + ";" + .data.endDate + ";" + .data.logs[].details + ";"')
        # TASK=$(curl -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cspm/v1/tasks/$TASK_ID")
        echo "Checking Role ..."
        REPORT_LINE=${REPORT_LINE}$(curl -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cloud/v2/accounts/$ACCOUNT/validateRole")
        echo "$REPORT_LINE" >> $OUTFILE
    else
        echo "No issues detected with account $ACCOUNT"
        echo "${ACCOUNT};$(echo $LAST_TASK | jq -r '.id + ";" + .status + ";" + .startDate + ";" + .endDate');;" >> $OUTFILE
    fi
}

if [[ "$ALL_ACCOUNTS" = true ]]
then
    for account_id in $(curl -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cloud/v2/accountIDs" | jq -r .[])
    do
        echo "All Accounts mode enabled"
        checkAccount $account_id
    done
else
    checkAccount $ACCOUNT_ID
fi

echo "Results recorded in file $OUTFILE"

exit 0