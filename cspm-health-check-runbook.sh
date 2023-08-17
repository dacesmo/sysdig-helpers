#! /bin/bash

REGION="us1"

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
      ALL_ACCOUNTS=true;
      shift
      ;;
     -r|--region)
       shift
       REGION=$1
       shift
       ;;
    *)
      echo "Invalid option"
      exit 13
      ;;
  esac
done

case "$(echo $REGION | tr '[:upper:]' '[:lower:]')" in
    us1) 
      SYSDIG_API_ENDPOINT="https://secure.sysdig.com"
      ;;
    us2)
      SYSDIG_API_ENDPOINT="https://us2.app.sysdig.com"
      ;;
    us4)
      SYSDIG_API_ENDPOINT="https://app.us4.sysdig.com"
      ;;
    eu1)
      SYSDIG_API_ENDPOINT="https://eu1.app.sysdig.com"
      ;;
    au1)
      SYSDIG_API_ENDPOINT="https://app.au1.sysdig.com"
      ;;
    *)
      echo "Invalid zone, make sure zone is entered among the valid ones ('us1', 'us2', 'us4', 'eu1' or 'au1'), if zone is not specified it will pick up default zone 'us1'."
      exit 12
      ;;
esac

[[ -z "$SECURE_API_TOKEN" ]] && echo "The API token must be set before running the script by exporting the var or run it as an env var before the script. I.e.:  'SECURE_API_TOKEN=<your_sysdig_secure_api_token> ${0}'" && exit 1

echo "Checking credentials ..."
[[ $(curl -s -XGET -w "%{http_code}" -o /dev/null -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/secure/onboarding/v2/status") -ne 200 ]] && echo "Login error, verify your token validity and the region you are connecting to." && exit 11 || echo "Credentials look good. Continuing ..."

OUTFILE="accounts_results.$(date +"%d-%m.%H%M%S").csv"
echo "Account ID;Last Scan ID;Last Scan Status;Start Date;End Date;Logs;Role Validation" > $OUTFILE

( [[ -z "$ACCOUNT_ID" ]] && [[ -z "$ALL_ACCOUNTS" ]] ) && echo "You must specify an account to look for using the -a flag or --account option, alternatively you can query all the accounts with flag -A or option --all-accounts" && exit 1

function checkAccount(){
    ACCOUNT=$1
    curl -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cloud/v2/accountIDs" |  jq | grep "\"$ACCOUNT\"" > /dev/null

    [[ $? -ne 0 ]] && echo "ERROR: Account \"$ACCOUNT\" not found" && exit 1

    LAST_TASK=$(curl -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cspm/v1/tasks?filter=parameters+contains+%27account%3A+${ACCOUNT}%27" | jq 'first(.[])|first(.[])')

    TASK_STATUS=$(echo "$LAST_TASK" | jq -r '.status')
    echo "Account \"$ACCOUNT\" Last Scan Status: \"$TASK_STATUS\"."
    if [[ $"$TASK_STATUS" == "Failed" ]] 
    then
        echo "Gathering additional information."
        TASK_ID=$(echo "$LAST_TASK" | jq -r '.id')
        REPORT_LINE="${ACCOUNT};"
        REPORT_LINE=${REPORT_LINE}$(curl -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cspm/v1/tasks/$TASK_ID" | jq -r '.data.id + ";" + .data.status + ";" + .data.startDate + ";" + .data.endDate + ";" + .data.logs[].details + ";"')
        echo "ERROR LOG: $(echo $REPORT_LINE | cut -d ';' -f6)"
        echo "Checking Role ..."
        REPORT_LINE=${REPORT_LINE}$(curl -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cloud/v2/accounts/$ACCOUNT/validateRole")
        echo $REPORT_LINE | cut -d ';' -f7
        echo "$REPORT_LINE" >> $OUTFILE
    else
        echo "No issues detected with account $ACCOUNT"
        echo "${ACCOUNT};$(echo $LAST_TASK | jq -r '.id + ";" + .status + ";" + .startDate + ";" + .endDate');;" >> $OUTFILE
    fi
}

if [[ "$ALL_ACCOUNTS" = true ]]
then
    echo "All Accounts mode enabled"
    for account_id in $(curl -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cloud/v2/accountIDs" | jq -r .[])
    do
        echo ""
        checkAccount $account_id
    done
else
    echo ""
    checkAccount $ACCOUNT_ID
fi

echo ""
echo "Results recorded in file $OUTFILE"

exit 0
