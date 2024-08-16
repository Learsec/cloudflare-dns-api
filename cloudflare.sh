#!/bin/bash
#TODO: add adding non-existent records.

#This is just for testing
#CERTBOT_DOMAIN="vault.learsec.com"
#CERTBOT_VALIDATION="sometestingvalue"

#includes TLD: example.com
domain=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')

#Extracts a subdomain, for www.example.com it would extract www
subdomain=$(expr match "$CERTBOT_DOMAIN" '\(.*\)\..*\..*')

newRecord="_acme-challenge.$subdomain"
scriptDir=$(dirname $0)
configFile="$scriptDir/config.json"

token=$(jq -r '.token' "$configFile")
mail=$(jq -r '.mail' "$configFile")
zone=$(jq -r '.zone' "$configFile")
apiUrl="https://api.cloudflare.com/client/v4/zones/$zone/dns_records"

function listDomains(){
    res=$(curl -s -X GET "$apiUrl" -H "X-Auth-Email: $mail" -H "Authorization: Bearer $token" -H "Content-Type: application/json")
    echo $res | jq '.result[]'
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

domains=$(listDomains)
recordMatch=$(findRecord "$domains" "$newRecord")
updateTXTRecord