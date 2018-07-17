#!/usr/bin/env bash

## Load variables from config file
source origin-cluster.conf

az group deployment show -g $AZURE_RG -n azuredeploy --query 'properties.outputs' | sed 's/ssh -p/ssh -i origin-ssh-key-p/' | grep -v String
