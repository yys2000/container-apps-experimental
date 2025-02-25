#!/bin/bash

set -e

RESOURCE_GROUP="ca-test-15"
LOCATION="canadacentral"
ENVIRONMENTNAME="ca-test-15"

SUBSCRIPTION=`az account show --query id -o tsv`
ACRNAME=$(az acr list -g $RESOURCE_GROUP --query [0].name -o tsv)
ACRLOGINSERVER=$(az acr show -n $ACRNAME -g $RESOURCE_GROUP --query loginServer -o tsv)
ACRPASSWORD=$(az acr credential show -n $ACRNAME -g $RESOURCE_GROUP --query passwords[0].value -o tsv)

declare -a apps=("fapp1" "fapp2")
timestamp=$(date +%s)

INSTKEY=`az monitor app-insights component show -g $RESOURCE_GROUP -a appins-$RESOURCE_GROUP --query instrumentationKey -o tsv`
SBCONN=`az servicebus namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name sb-$RESOURCE_GROUP --name RootManageSharedAccessKey --query primaryConnectionString -o tsv`
STACCOUNT=`az storage account list -g $RESOURCE_GROUP --query [0].id -o tsv`
STCONN=`az storage account show-connection-string --ids $STACCOUNT --query connectionString -o tsv`

mkdir -p /tmp/deployment
if [ -e /tmp/deployment/* ]; then
    rm /tmp/deployment/*
fi

cat <<EOF >/tmp/deployment/env.json
[
    {
        "name": "servicebusconnection",
        "secretRef": "servicebusconnection",
        "value": null
    },
    {
        "name": "AzureWebJobsStorage",
        "secretRef": "storageconnection",
        "value": null
    },
    {
        "name": "queuename",
        "secretRef": null,
        "value": "queue1"
    },
    {
        "name": "APPINSIGHTS_INSTRUMENTATIONKEY",
        "secretRef": null,
        "value": "$INSTKEY"
    },
    {
        "name": "AzureFunctionsWebHost__hostId",
        "secretRef": null,
        "value": "HOSTID"
    }
]
EOF

for app in "${apps[@]}"
do
    echo "$app"

    if [ "$1" == "skipbuild" ]; then
        timestamp=`az acr repository show-tags -n $ACRNAME --repository $app --top 1 --orderby time_desc -o tsv`
    else
        az acr build -t $ACRLOGINSERVER/$app:$timestamp -r $ACRNAME ../$app
    fi

    if [ $app = 'fapp1' ]; then
        scaleby=Http
    else
        scaleby=Queue
    fi

    # fix hostid https://github.com/Azure/azure-functions-host/wiki/Host-IDs
    HOSTID=`head /dev/urandom | tr -dc a-z0-9 | head -c 20`    
    sed s/HOSTID/$HOSTID/ /tmp/deployment/env.json > /tmp/deployment/env$app.json

    az deployment group create -n $app \
    -g $RESOURCE_GROUP \
    --template-file ./fapp.bicep \
    -p  name=$app \
        environmentName=$ENVIRONMENTNAME \
        containerImage=$ACRLOGINSERVER/$app:$timestamp \
        containerPort=80 \
        registry=$ACRLOGINSERVER \
        registryUsername=$ACRNAME \
        registryPassword="$ACRPASSWORD" \
        serviceBusConnection="$SBCONN" \
        storageConnection="$STCONN" \
        useExternalIngress=true \
        envVars=@/tmp/deployment/env$app.json \
        scaleBy=$scaleby

done

for app in "${apps[@]}"
do
    fqdn=`az containerapp show -n $app -g $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv --only-show-errors`
    echo https://$fqdn/api/health
done

