#!/bin/bash

# Setup Infrastructure Script
# Creates Key Vaults and Storage Accounts for all environments

set -e

# Configuration
RESOURCE_GROUP="nanba-github"
LOCATION="uksouth"
SERVICE_PRINCIPAL_OBJECT_ID="9fa6cb05-0e3e-4e1b-89fc-0ca732333d91"
ENVIRONMENTS=("dev" "test" "prod")

echo "🚀 Setting up infrastructure for Nanba Databricks project"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Service Principal: $SERVICE_PRINCIPAL_OBJECT_ID"
echo "=================================================="

# Function to create storage account
create_storage_account() {
    local env=$1
    local storage_name="stdluk${env}"
    local container_name=""
    
    case $env in
        dev) container_name="bronze" ;;
        test) container_name="silver" ;;
        prod) container_name="gold" ;;
    esac
    
    echo "Creating storage account: $storage_name"
    
    # Create storage account
    az storage account create \
        --name $storage_name \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku Standard_LRS \
        --kind StorageV2 \
        --enable-hierarchical-namespace true \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --default-action Deny \
        --bypass AzureServices \
        --tags environment=$env project=nanba-databricks managedBy=script
    
    # Create container
    echo "Creating container: $container_name"
    az storage container create \
        --name $container_name \
        --account-name $storage_name \
        --public-access off \
        --auth-mode login
    
    # Assign Storage Blob Data Contributor role
    echo "Assigning Storage Blob Data Contributor role"
    az role assignment create \
        --role "Storage Blob Data Contributor" \
        --assignee $SERVICE_PRINCIPAL_OBJECT_ID \
        --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$storage_name"
    
    echo "✅ Storage account $storage_name created successfully"
}

# Function to create key vault
create_key_vault() {
    local env=$1
    local kv_name="kv-${env}-dbws"
    
    echo "Creating key vault: $kv_name"
    
    # Create key vault
    az keyvault create \
        --name $kv_name \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku standard \
        --enable-soft-delete true \
        --soft-delete-retention-days 90 \
        --enable-purge-protection true \
        --default-action Deny \
        --bypass AzureServices \
        --tags environment=$env project=nanba-databricks managedBy=script
    
    # Set access policy for service principal
    echo "Setting access policy for service principal"
    az keyvault set-policy \
        --name $kv_name \
        --object-id $SERVICE_PRINCIPAL_OBJECT_ID \
        --key-permissions get list update create import delete recover backup restore decrypt encrypt unwrapKey wrapKey verify sign purge \
        --secret-permissions get list set delete recover backup restore purge \
        --certificate-permissions get list update create import delete recover backup restore managecontacts manageissuers getissuers listissuers setissuers deleteissuers purge
    
    echo "✅ Key vault $kv_name created successfully"
}

# Login check
echo "Checking Azure CLI login..."
if ! az account show >/dev/null 2>&1; then
    echo "❌ Please login to Azure CLI first: az login"
    exit 1
fi

echo "✅ Logged in as: $(az account show --query user.name -o tsv)"

# Create resources for each environment
for env in "${ENVIRONMENTS[@]}"; do
    echo ""
    echo "🔧 Setting up $env environment"
    echo "================================"
    
    # Create storage account
    create_storage_account $env
    
    # Create key vault
    create_key_vault $env
    
    echo "✅ $env environment setup completed"
done

echo ""
echo "🎉 All infrastructure setup completed successfully!"
echo ""
echo "Created resources:"
echo "=================="
for env in "${ENVIRONMENTS[@]}"; do
    echo "Environment: $env"
    echo "  - Storage Account: stdluk${env}"
    echo "  - Key Vault: kv-${env}-dbws"
    echo "  - Container: $(case $env in dev) echo bronze ;; test) echo silver ;; prod) echo gold ;; esac)"
done

echo ""
echo "Next steps:"
echo "==========="
echo "1. Push code to GitHub to trigger CI/CD"
echo "2. Set up GitHub environment secrets"
echo "3. Run Unity Catalog bootstrap notebook"
echo "4. Test ELT pipeline"

echo ""
echo "📋 GitHub Secrets to configure:"
echo "  - ARM_CLIENT_ID: <your-service-principal-client-id>"
echo "  - ARM_CLIENT_SECRET: <your-service-principal-secret>"
echo "  - ARM_TENANT_ID: <your-azure-tenant-id>"
echo "  - ARM_SUBSCRIPTION_ID: <your-azure-subscription-id>"
echo "  - GITHUB_TOKEN: <your-github-pat-token>"