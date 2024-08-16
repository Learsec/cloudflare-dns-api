#!/bin/bash
#TODO: add adding non-existent records. Add validations on responses (empty or error). Add validation on data (empty or invalid). Add validation on jq outputs (error, empty or multiple)

#This is just for testing
CERTBOT_DOMAIN="vaulting.learsec.com"
CERTBOT_VALIDATION="sometestingvalue"

#includes TLD: example.com
domain=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')

#Extracts a subdomain, for www.example.com it would extract www
subdomain=$(expr match "$CERTBOT_DOMAIN" '\(.*\)\..*\..*')

newRecord="_acme-challenge.$subdomain"
scriptDir=$(dirname $0)
logFile="$scriptDir/logfile.log"
configFile="$scriptDir/config.json"

###
# Writes to a log file ($logFile), by default it writes <hh:mm:ss message>.
# $1 the <message> to be writen
#
# $2: set it to 1 to include the day, month and year before hh:mm:ss
# omit or use any other value to keep the default format.
function writeLog(){
  if [ ! -z $2 ] && [ $2 -eq 1 ]; then
    # Output includes the day, month and year
    echo "[$(date +'%D %H:%M:%S')] $1" >> $logFile
  else
    echo "[$(date +'%H:%M:%S')] $1" >> $logFile
  fi
}
writeLog '----------Begin log----------' 1
writeLog "Will attempt creating $newRecord for $domain with value $CERTBOT_VALIDATION"

function jqInstalled(){
  echo $([[ ! -n $(apt -qq list jq 2>/dev/null | grep 'instal') ]]; echo $?)
}
function curlInstalled(){
  echo $([[ ! -n $(apt -qq list curl 2>/dev/null | grep 'instal') ]]; echo $?)
}
function prereqsInstalled(){
  if [[ $(jqInstalled) == 1 && $(curlInstalled) == 1 ]]; then 
    echo 1 
  else 
    echo 0
  fi
}

#Installs jq and curl
function installPrereqs(){
  unmetReqs=""

  if [ $(prereqsInstalled) -eq 1 ]; then
    writeLog "Prereqs already installed"
    return
  fi

  isRoot=$([[ "$EUID" -eq 0 ]]; echo $?)

  if [[ $(curlInstalled) -eq 0 ]]; then
    if [ $isRoot -ne 0  ]; then
        unmetReqs=$'\n- Curl'
    else
        writeLog "Installing curl"
        apt install curl -y
    fi
  fi

  if [[ $(jqInstalled) -eq 0 ]]; then
    if [ $isRoot -ne 0  ]; then 
        unmetReqs+=$'\n- Jq'
    else
        writeLog "Installing jq"
        apt install jq -y
    fi
  fi

  if [ $isRoot -ne 0 ]; then 
    logMessage="Please re-run as root or install the following dependencies manually: $unmetReqs"
    writeLog "$logMessage"
    echo "$logMessage" > /dev/tty 
    exit 1
  fi
}

function listDomains(){
    res=$(curl -s -X GET "$apiUrl" -H "X-Auth-Email: $mail" -H "Authorization: Bearer $token" -H "Content-Type: application/json")
    if [[ $(echo $res | jq '.success') = "true" ]]; then 
      echo $res | jq '.result[]'
    else
      logMessage="Couldn't list domains, check error below and try again."
      writeLog "$logMessage"
      echo "$logMessage $res" > /dev/tty 
      writeLog "$res"
      exit 1
    fi
}

function findRecord(){
    #The dot is added only here just to avoid finding matches on
    #subdomains containing the subdomain string, for example:
    #if the subdomain is "test" and we have "test" and "test-site" records in place
    #they would both be found by the selector. Using the dot at the end ensures only
    #getting the one called "test".
    selector="select(.name | contains(\"$2.\"))"
    record=$(echo $1 | jq "$selector")
    echo $record
}

function updateTXTRecord(){
    id=$(echo $recordMatch | jq -r ".id")
    data=$( jq -r -n --arg content "$CERTBOT_VALIDATION" --arg name "$newRecord" --arg type "TXT" --arg comment "" --arg id "$id" '{content: $content, name: $name, type: $type, comment: $comment, id: $id, tags: [], ttl: 1}')
    curl --request PATCH "$apiUrl/$id" -H "X-Auth-Email: $mail" -H "Authorization: Bearer $token" -H "Content-Type: application/json"  --data "$data"
}

#updateTXTRecord
installPrereqs
token=$(jq -r '.token' "$configFile")
mail=$(jq -r '.mail' "$configFile")
zone=$(jq -r '.zone' "$configFile")
apiUrl="https://api.cloudflare.com/client/v4/zonaes/$zone/dns_records"

domains=$(listDomains)
#recordMatch=$(findRecord "$domains" "$newRecord")
#echo $recordMatch
#if ($recordMatch)