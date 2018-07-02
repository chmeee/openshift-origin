#!/usr/bin/env bash

##
## Personalize these two parameters
##
NODECOUNT=2		  # Set the number of worker nodes, minimum 2
AZURE_RG=origin		  # Set the name of the resource group for the cluster resources, except the keyvault
			  # This name will be used for the resource group for the keyvault
AZURE_LOC="westeurope"	  # Set the location where you want to deploy the cluster
AADCLIENT_ID="xxxxx"	  # Set your service principal ID (appId)
AADCLIENT_SECRET="xxxxx"  # Set your service principal (password)

## To create your principal run this command:
## az ad sp create-for-rbac

## Password will  be autogenerated, if you want to set one yourself, replace the following line
PASSWORD=$(head -n 50 /dev/urandom | tr -dc 'a-zA-Z0-9-_@#%^_+:?' | fold -w 12 | head -n 1)

##
## Here be dragons
##
KEYVAULT_RG=$AZURE_RG-vault
KEYVAULT_NAME=$AZURE_RG-vault
KEYVAULT_SECRET=$AZURE_RG-key
SSHKEY_NAME=origin-ssh-key

if [[ $AADCLIENT_ID == "xxxxx" || $AADCLIENT_SECRET == "xxxxx" ]]; then
  echo "Error: Before running this script please edit it to set the AADCLIENT_ID and AADCLIENT_SECRET variables"
  exit 1
fi

if [[ ! -f origin-ssh-key ]]; then
  echo "##"
  echo "## Creating a new ssh key"
  echo "##"
  ssh-keygen -q -N "" -f $SSHKEY_NAME
fi

SSHPUBLIC_KEY=$(cat $SSHKEY_NAME.pub | awk '{ print $1, $2}')

echo "##"
echo "## Creating a new keyvault and adding the ssh key"
echo "##"
az group create -n $KEYVAULT_RG -l $AZURE_LOC
az keyvault create -n $KEYVAULT_NAME -g $KEYVAULT_RG -l $AZURE_LOC --enabled-for-template-deployment true
az keyvault secret set --vault-name $KEYVAULT_NAME -n $KEYVAULT_SECRET --file $SSHKEY_NAME

if [[ $? != 0 ]]; then echo "Error: Creating a new keyvault and adding the ssh key failed"; exit $?; fi

echo "##"
echo "## Generating the azuredeploy.parameters.json file from the template"
echo "##"
sed -e "s#NODECOUNT#$NODECOUNT#;
	s#AADCLIENT_ID#$AADCLIENT_ID#;
	s#AADCLIENT_SECRET#$AADCLIENT_SECRET#;
	s#PASSWORD#$PASSWORD#;
	s#KEYVAULT_RG#$KEYVAULT_RG#;
	s#KEYVAULT_NAME#$KEYVAULT_NAME#;
	s#KEYVAULT_SECRET#$KEYVAULT_SECRET#;
	s#SSHPUBLIC_KEY#$SSHPUBLIC_KEY#" azuredeploy.template.json > azuredeploy.parameters.json

if [[ $? != 0 ]]; then echo "Error: Generating the azuredeploy.parameters.json file failed"; exit $?; fi

echo "##"
echo "## Launching the cluster deployment"
echo "##"
az group create --name $AZURE_RG --location $AZURE_LOC
az group deployment create --resource-group $AZURE_RG --template-file azuredeploy.json --parameters @azuredeploy.parameters.json --no-wait 

if [[ $? != 0 ]]; then echo "Error: Launching the cluster deployment failed"; exit $?; fi

echo "## Deployment has launched and will take around 30min. to finish"
echo "## Please monitor your deployment on the Azure portal on: Resource groups > $AZURE_RG > Deployments > azuredeploy"
echo "## When finished you will see the URL for console and SSH access as outputs of the deployment"
echo "## Your credentials for login to the web console are: user=origin, password=$PASSWORD"
echo "## Remember to add -i $SSHKEY_NAME to the ssh command to log in"
