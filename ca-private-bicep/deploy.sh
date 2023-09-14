#!/bin/bash

set -e

RESOURCE_GROUP="ca-test-6"
LOCATION="westus"
ENVIRONMENTNAME="ca-kw-6"

az deployment sub create -n $RESOURCE_GROUP -f main.bicep -p name=$RESOURCE_GROUP -l $LOCATION
