#!/bin/bash

## Functions

helpUsage()
{
   echo ""
   echo "Usage: $0 [-a single-account | -A all-accounts | -l account-list(comma separated)] [-t secure-api-token] [-r region(us1, us2, us4, eu1, au1)] [-o output-file] [-i] [-h]"
   echo -e "\t-a <single-account> return status of a single account"
   echo -e "\t-A return status of ALL accounts"
   echo -e "\t-l <account,accont...> return status of a list of accounts (comma separated)"
   echo -e "\t-t <secure-api-token> Sysdig Secure API Token"
   echo -e "\t-r <region> Sysdig Secure Region (us1, us2, us4, eu1, au1) default: eu1"
   echo -e "\t-o <outputfile> output file name, default: accounts_results.<date>.csv"
   echo -e "\t-i insecure connection, not check certificates (behin proxy, etc), default: false USE AT YOUR OWN RISK"
   echo -e "\t-h print this Help"
   exit # Exit script after printing help
}

function checkAccount(){
    ACCOUNT=$1
    LAST_TASK=$(curl ${INSECURE} -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cspm/v1/tasks?filter=parameters+contains+%27account%3A+${ACCOUNT}%27" | jq 'first(.[])|first(.[])')

    TASK_STATUS=$(echo "$LAST_TASK" | jq -r '.status')
    echo "Account \"$ACCOUNT\" Last Scan Status: \"$TASK_STATUS\"."
    if [[ $"$TASK_STATUS" == "Failed" ]] 
    then
        echo "Gathering additional information."
        TASK_ID=$(echo "$LAST_TASK" | jq -r '.id')
        REPORT_LINE="${ACCOUNT};"
        REPORT_LINE=${REPORT_LINE}$(curl ${INSECURE} -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cspm/v1/tasks/$TASK_ID" | jq -r '.data.id + ";" + .data.status + ";" + .data.startDate + ";" + .data.endDate + ";" + .data.logs[].details + ";"')
        echo "ERROR LOG: $(echo $REPORT_LINE | cut -d ';' -f6)"
        echo "Checking Role ..."
        REPORT_LINE=${REPORT_LINE}$(curl ${INSECURE} -s --header "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cloud/v2/accounts/$ACCOUNT/validateRole")
        echo $REPORT_LINE | cut -d ';' -f7
        echo "$REPORT_LINE" >> $OUTFILE
    else
        echo "No issues detected with account $ACCOUNT"
        echo "${ACCOUNT};$(echo $LAST_TASK | jq -r '.id + ";" + .status + ";" + .startDate + ";" + .endDate');;" >> $OUTFILE
    fi
}

## Vars & Def values

REGION="eu1"
INSECURE=""
OUTFILE="accounts_results.$(date +"%d-%m.%H%M%S").csv"
ALL_ACCOUNTS=false

##  Main
while getopts "a:Al:t:r:o:ih" opt
do
   case "$opt" in
      a ) ACCOUNT_ID="$OPTARG"       ;;
      A ) ALL_ACCOUNTS=true          ;;
      l ) ACCOUNT_IDS="$OPTARG"      ;;
      t ) SECURE_API_TOKEN="$OPTARG" ;;
      r ) REGION="$OPTARG"           ;;
      o ) OUTFILE="$OPTARG"          ;;
      i ) INSECURE="-k"              ;;
      h ) helpUsage                  ;; 
   esac
done

# ALL Account over individual or account list
if $ALL_ACCOUNTS ; then
    echo "All Accounts mode enabled"
    ACCOUNT_ID=""
    ACCOUNT_IDS=""
else
  if [[ -z "$ACCOUNT_ID" ]] && [[ -z "$ACCOUNT_IDS" ]] ; then
    echo "You must specify an account to look for using the -a flag or -l flag, alternatively you can query all the accounts with flag -A"
    exit 1
  fi
  if [[ ! -z "$ACCOUNT_IDS" ]] ; then    # List over individual account
    echo "Account list informed. Using list: ${ACCOUNT_IDS}"
  elif [[ ! -z "$ACCOUNT_ID" ]] ; then   # Individual account
    echo "Individual account informed. Using account: ${ACCOUNT_ID}"
    ACCOUNT_IDS="$ACCOUNT_ID"
  fi
fi

case "$(echo $REGION | tr '[:upper:]' '[:lower:]')" in
    us1 ) SYSDIG_API_ENDPOINT="https://secure.sysdig.com"      ;;
    us2 ) SYSDIG_API_ENDPOINT="https://us2.app.sysdig.com"     ;;
    us4 ) SYSDIG_API_ENDPOINT="https://app.us4.sysdig.com"     ;;
    eu1 ) SYSDIG_API_ENDPOINT="https://eu1.app.sysdig.com"     ;;
    au1 ) SYSDIG_API_ENDPOINT="https://app.au1.sysdig.com"     ;;
    *)
      echo "Invalid zone, make sure zone is entered among the valid ones ('us1', 'us2', 'us4', 'eu1' or 'au1'), if zone is not specified it will pick up default zone 'us1'."
      exit
      ;;
esac

[[ -z "$SECURE_API_TOKEN" ]] && echo "The API token must be set before running the script by exporting the var or run it as an env var before the script. I.e.:  'SECURE_API_TOKEN=<your_sysdig_secure_api_token> ${0}'" && exit 1

echo "Checking credentials ..."
[[ $(curl ${INSECURE} -s -XGET -w "%{http_code}" -o /dev/null -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/secure/onboarding/v2/status") -ne 200 ]] && echo "Login error, verify your token validity and the region you are connecting to." && exit 11 || echo "Credentials look good. Continuing ..."

echo "Account ID;Last Scan ID;Last Scan Status;Start Date;End Date;Logs;Role Validation" > $OUTFILE

# Dump all ACCOUNTS IDS only once
echo "Retrieving accounts ..."
readarray -t SYSDIG_ACCOUNTS < <(curl ${INSECURE} -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "${SYSDIG_API_ENDPOINT}/api/cloud/v2/accountIDs" | jq -rc '.[]' )

if [[ "$ALL_ACCOUNTS" = true ]]
then
    for account_id in "${SYSDIG_ACCOUNTS[@]}"; do
        checkAccount $account_id
    done
else
    for account_id in $(echo $ACCOUNT_IDS | tr ',' ' '); do
        if [[ ${SYSDIG_ACCOUNTS[@]} =~ $account_id ]]
        then
          checkAccount $account_id
        else
          echo "Account $account_id not found"
        fi
    done
fi

echo ""
echo "Results recorded in file $OUTFILE"

exit 0
