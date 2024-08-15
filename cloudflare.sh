#!/bin/bash
#includes TLD: example.com
domain=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')

#Extracts a subdomain, for www.example.com it would extract www
subdomain=$(expr match "$CERTBOT_DOMAIN" '\(.*\)\..*\..*')

scriptDir=$(dirname $0)
configFile="$scriptDir/config.json"

key=$(jq '.key' "$configFile")
mail=$(jq '.mail' "$configFile")
zone=$(jq '.zone' "$configFile")

apiUrl="https://api.cloudflare.com/client/v4/zones/$zone/dns_records"