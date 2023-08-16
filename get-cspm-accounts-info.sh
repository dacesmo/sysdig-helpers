#! /bin/bash

TOTALS_ONLY=false


# Check for SECURE_API_TOKEN, else terminate with error code 1
[[ -z "$SECURE_API_TOKEN" ]] && echo "The API token must be set before running the script by exporting the var or run it as an env var before the script. I.e.:  'SECURE_API_TOKEN=<your_sysdig_secure_api_token> ${0}'" && exit 1

while test $# -gt 0; do
  case "$1" in
    -t|--secure-api-token)
      shift
      SECURE_API_TOKEN=$1
      shift
      ;;
    -T|--totals-only)
      shift
      TOTALS_ONLY=true
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


function getAccountsTotal(){

    ACCOUNTS=$(curl -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cloud/v2/dataSources/accounts?limit=5000&offset=0" | jq -r '.[] | .id' 2>/dev/null)
    if [[ -z $ACCOUNTS ]]
    then
        # If there are no accounts found, terminate with error code 2
        if [ $OFFSET -eq 0 ]
        then
            echo "ERROR: No accounts found as onboarded in your Sysdig instance"
            exit 2
        fi
        # If no more accounts to query, exit with success
        echo ""
        break
    else
        echo Total accounts found: $(echo "$ACCOUNTS" | wc -l | tr -d ' ')
    fi

}

if [ "$TOTALS_ONLY" = true ]
then
    getAccountsTotal
    exit 0
fi

# Set Output File
OUTPUT_FILE="accounts_info.csv"

# Set csv file headers.
echo "Account ID;Provider;Alias;Role Available;Role Name;CIEM Enabled;CIEM Enabled at;Component" > $OUTPUT_FILE

# Set Offset and Limit for account query and account counter for statistics.
OFFSET=0
LIMIT=1000
ACCT_COUNTER=0

# TEST_LOOPER=0 # Only to query test the loops and query small number of accounts. Please don't uncomment.

while true
do
    # Query all the accounts, this API seems to support up to 1000 results.
    ACCOUNTS=$(curl -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cloud/v2/dataSources/accounts?limit=${LIMIT}&offset=${OFFSET}" | jq -r '.[] | .id' 2>/dev/null)

    # Test no accounts returned from query #
    # ACCOUNTS=""
    ########################################

    if [[ -z $ACCOUNTS ]]
    then

        # Test no results but offset set to 1 #
        # OFFSET=1
        #######################################

        # If there are no accounts found, terminate with error code 2
        if [ $OFFSET -eq 0 ]
        then
            echo "ERROR: No accounts found as onboarded in your Sysdig instance"
            exit 2
        fi
        # If no more accounts to query, exit with success
        echo ""
        break
    fi
    
    # Query accounts individually and save the info to the $OUTPUT_FILE file.
    for ACCOUNT_ID in $(echo "$ACCOUNTS")
    do
        curl -s -XGET -H "Authorization: Bearer $SECURE_API_TOKEN" -H 'Content-Type: application/json' "https://eu1.app.sysdig.com/api/cloud/v2/accounts/${ACCOUNT_ID}" | jq -r 'join(";")' | tee -a $OUTPUT_FILE
        ((ACCT_COUNTER++))
        
        ## Test the loops and data extracted ##
        # ((TEST_LOOPER++))
        # if [ $TEST_LOOPER -eq 5 ]
        # then
        #     ((LIMIT++))
        #     break
        # fi
        #######################################
        
    done

    # If the number of accounts is lower than the LIMIT, break the loop. This is just to save 1 extra API Call.
    if [ $(echo "$ACCOUNTS" | wc -l | tr -d ' ') -lt $LIMIT ]
    then
        echo ""
        break
    fi

    # Increase the offset to the limit size
    ((OFFSET+=LIMIT))

done

echo "Total Accounts Processed: $ACCT_COUNTER"

# Success
exit 0