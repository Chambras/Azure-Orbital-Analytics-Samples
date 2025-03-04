#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/..; pwd)"

ENV_CODE=${1:-${ENV_CODE}}
PIPELINE_NAME=${2:-${PIPELINE_NAME}}

BATCH_ACCOUNT_NAME=${3:-${BATCH_ACCOUNT_NAME}}
BATCH_ACCOUNT_RG_NAME=${4:-$BATCH_ACCOUNT_RG_NAME}
BATCH_STORAGE_ACCOUNT_NAME=${5:-${BATCH_STORAGE_ACCOUNT_NAME}}
KEY_VAULT_NAME=${6:-${KEY_VAULT_NAME}}

RAW_STORAGE_ACCOUNT_RG=${7:-${RAW_STORAGE_ACCOUNT_RG:-"${ENV_CODE}-data-rg"}}
RAW_STORAGE_ACCOUNT_NAME=${8:-${RAW_STORAGE_ACCOUNT_NAME}}

SYNAPSE_WORKSPACE_RG=${9:-${SYNAPSE_WORKSPACE_RG:-"${ENV_CODE}-pipeline-rg"}}
SYNAPSE_WORKSPACE_NAME=${10:-${SYNAPSE_WORKSPACE_NAME}}
SYNAPSE_STORAGE_ACCOUNT_NAME=${11:-${SYNAPSE_STORAGE_ACCOUNT_NAME}}
SYNAPSE_POOL=${12:-${SYNAPSE_POOL}}

set -ex

if [[ -z "$BATCH_ACCOUNT_NAME" ]] && [[ -z "$BATCH_ACCOUNT_RG_NAME" ]]; then
    BATCH_ACCOUNT_RG_NAME="${ENV_CODE}-orc-rg"
fi
if [[ -z "$BATCH_ACCOUNT_NAME" ]]; then
    BATCH_ACCOUNT_NAME=$(az batch account list --query "[?tags.type && tags.type == 'batch'].name" -o tsv -g $BATCH_ACCOUNT_RG_NAME)
fi
if [[ -z "$BATCH_ACCOUNT_RG_NAME" ]]; then
    BATCH_ACCOUNT_ID=$(az batch account list --query "[?name == '${BATCH_ACCOUNT_NAME}'].id" -o tsv)
    BATCH_ACCOUNT_RG_NAME=$(az resource show --ids ${BATCH_ACCOUNT_ID} --query resourceGroup -o tsv)
fi
if [[ -z "$RAW_STORAGE_ACCOUNT_NAME" ]]; then
    RAW_STORAGE_ACCOUNT_NAME=$(az storage account list --query "[?tags.store && tags.store == 'raw'].name" -o tsv -g $RAW_STORAGE_ACCOUNT_RG)
fi
if [[ -z "$SYNAPSE_STORAGE_ACCOUNT_NAME" ]]; then
    SYNAPSE_STORAGE_ACCOUNT_NAME=$(az storage account list --query "[?tags.store && tags.store == 'synapse'].name" -o tsv -g $SYNAPSE_WORKSPACE_RG)
fi
if [[ -z "$BATCH_STORAGE_ACCOUNT_NAME" ]]; then
    BATCH_STORAGE_ACCOUNT_NAME=$(az storage account list --query "[?tags.store && tags.store == 'batch'].name" -o tsv -g $BATCH_ACCOUNT_RG_NAME)
    if [[ -z "$BATCH_STORAGE_ACCOUNT_NAME" ]]; then
        BATCH_STORAGE_ACCOUNT_NAME=$(az storage account list --resource-group $BATCH_ACCOUNT_RG_NAME --query [0].name -o tsv)
    fi
fi
if [[ -z "$BATCH_ACCOUNT_LOCATION" ]]; then
    BATCH_ACCOUNT_LOCATION=$(az batch account list --query "[?name == '${BATCH_ACCOUNT_NAME}'].location" -o tsv)
fi
if [[ -z "$KEY_VAULT_NAME" ]]; then
    KEY_VAULT_NAME=$(az keyvault list --query "[?tags.usage && tags.usage == 'linkedService'].name" -o tsv -g $SYNAPSE_WORKSPACE_RG)
fi
if [[ -z "$SYNAPSE_WORKSPACE_NAME" ]]; then
    SYNAPSE_WORKSPACE_NAME=$(az synapse workspace list --query "[?tags.workspaceId && tags.workspaceId == 'default'].name" -o tsv -g $SYNAPSE_WORKSPACE_RG)
fi
if [[ -z "$SYNAPSE_POOL" ]]; then
    SYNAPSE_POOL=$(az synapse spark pool list --workspace-name $SYNAPSE_WORKSPACE_NAME --resource-group $SYNAPSE_WORKSPACE_RG --query "[?tags.poolId && tags.poolId == 'default'].name" -o tsv)
fi

echo 'Retrieved resource from Azure and ready to package'
PACKAGING_SCRIPT="python3 ${PRJ_ROOT}/deploy/package.py --raw_storage_account_name $RAW_STORAGE_ACCOUNT_NAME \
    --synapse_storage_account_name $SYNAPSE_STORAGE_ACCOUNT_NAME \
    --batch_storage_account_name $BATCH_STORAGE_ACCOUNT_NAME \
    --batch_account $BATCH_ACCOUNT_NAME \
    --linked_key_vault $KEY_VAULT_NAME \
    --synapse_pool_name $SYNAPSE_POOL \
    --location $BATCH_ACCOUNT_LOCATION \
    --pipeline_name $PIPELINE_NAME"

echo $PACKAGING_SCRIPT
echo 'Starting packaging script ...'
$PACKAGING_SCRIPT
echo 'Packaging script completed'