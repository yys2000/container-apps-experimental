#!/bin/bash

set -e

RESOURCE_GROUP="ca-test-8"
LOCATION="westus"
ENVIRONMENTNAME="ca-kw-8"

SUBSCRIPTION=`az account show --query id -o tsv`
ACRNAME=$(az acr list -g $RESOURCE_GROUP --query [0].name -o tsv)
ACRLOGINSERVER=$(az acr show -n $ACRNAME -g $RESOURCE_GROUP --query loginServer -o tsv)
ACRPASSWORD=$(az acr credential show -n $ACRNAME -g $RESOURCE_GROUP --query passwords[0].value -o tsv)
REDISNAME=$(az redis list -g $RESOURCE_GROUP --query [0].name -o tsv)

declare -a apps=("app1" "app2")
timestamp=$(date +%s)

for app in "${apps[@]}"
do
    echo "$app"

    if [ "$1" == "skipbuild" ]; then
        timestamp=`az acr repository show-tags -n $ACRNAME --repository $app --top 1 --orderby time_desc -o tsv`
    else
        az acr build -t $ACRLOGINSERVER/$app:$timestamp -r $ACRNAME ../$app
    fi

    az deployment group create -n $app \
    -g $RESOURCE_GROUP \
    --template-file ./app.bicep \
    -p  name=$app \
        environmentName=$ENVIRONMENTNAME \
        containerImage=$ACRLOGINSERVER/$app:$timestamp \
        containerPort=80 \
        registry=$ACRLOGINSERVER \
        registryUsername=$ACRNAME \
        registryPassword="$ACRPASSWORD" \
        redisName=$REDISNAME \
        useExternalIngress=true

done

for app in "${apps[@]}"
do
    fqdn=`az containerapp show -g $RESOURCE_GROUP -n $app --query properties.configuration.ingress.fqdn -o tsv --only-show-errors`
    echo https://$fqdn/health
    echo https://$fqdn/health-remote
done
