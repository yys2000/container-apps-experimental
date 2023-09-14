#!/bin/bash

RESOURCE_GROUP="ca-test-9"

for vm in `az vm list -g ${RESOURCE_GROUP} --query [].id -o tsv`; do az vm start --id $vm; done