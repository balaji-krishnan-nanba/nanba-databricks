# Setup Infrastructure PowerShell Script
# Creates Key Vaults and Storage Accounts for all environments

param(
    [string]$ResourceGroup = "nanba-github",
    [string]$Location = "uksouth",
    [string]$ServicePrincipalObjectId = "9fa6cb05-0e3e-4e1b-89fc-0ca732333d91"
)

$ErrorActionPreference = "Stop"

# Configuration
$Environments = @("dev", "test", "prod")
$ContainerMap = @{
    "dev" = "bronze"
    "test" = "silver"
    "prod" = "gold"
}

Write-Host "🚀 Setting up infrastructure for Nanba Databricks project" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Location: $Location"
Write-Host "Service Principal: $ServicePrincipalObjectId"
Write-Host "==================================================" -ForegroundColor Yellow

# Function to create storage account
function New-StorageAccount {
    param(
        [string]$Environment,
        [string]$ResourceGroup,
        [string]$Location,
        [string]$ServicePrincipalObjectId
    )
    
    $StorageName = "stdluk$Environment"
    $ContainerName = $ContainerMap[$Environment]
    
    Write-Host "Creating storage account: $StorageName" -ForegroundColor Cyan
    
    try {
        # Create storage account
        az storage account create `
            --name $StorageName `
            --resource-group $ResourceGroup `
            --location $Location `
            --sku Standard_LRS `
            --kind StorageV2 `
            --enable-hierarchical-namespace true `
            --min-tls-version TLS1_2 `
            --allow-blob-public-access false `
            --default-action Deny `
            --bypass AzureServices `
            --tags environment=$Environment project=nanba-databricks managedBy=powershell
        
        # Create container
        Write-Host "Creating container: $ContainerName" -ForegroundColor Cyan
        az storage container create `
            --name $ContainerName `
            --account-name $StorageName `
            --public-access off `
            --auth-mode login
        
        # Get subscription ID
        $SubscriptionId = (az account show --query id -o tsv)
        
        # Assign Storage Blob Data Contributor role
        Write-Host "Assigning Storage Blob Data Contributor role" -ForegroundColor Cyan
        az role assignment create `
            --role "Storage Blob Data Contributor" `
            --assignee $ServicePrincipalObjectId `
            --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$StorageName"
        
        Write-Host "✅ Storage account $StorageName created successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to create storage account $StorageName`: $($_.Exception.Message)"
        throw
    }
}

# Function to create key vault
function New-KeyVault {
    param(
        [string]$Environment,
        [string]$ResourceGroup,
        [string]$Location,
        [string]$ServicePrincipalObjectId
    )
    
    $KvName = "kv-$Environment-dbws"
    
    Write-Host "Creating key vault: $KvName" -ForegroundColor Cyan
    
    try {
        # Create key vault
        az keyvault create `
            --name $KvName `
            --resource-group $ResourceGroup `
            --location $Location `
            --sku standard `
            --enable-soft-delete true `
            --soft-delete-retention-days 90 `
            --enable-purge-protection true `
            --default-action Deny `
            --bypass AzureServices `
            --tags environment=$Environment project=nanba-databricks managedBy=powershell
        
        # Set access policy for service principal
        Write-Host "Setting access policy for service principal" -ForegroundColor Cyan
        az keyvault set-policy `
            --name $KvName `
            --object-id $ServicePrincipalObjectId `
            --key-permissions get list update create import delete recover backup restore decrypt encrypt unwrapKey wrapKey verify sign purge `
            --secret-permissions get list set delete recover backup restore purge `
            --certificate-permissions get list update create import delete recover backup restore managecontacts manageissuers getissuers listissuers setissuers deleteissuers purge
        
        Write-Host "✅ Key vault $KvName created successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to create key vault $KvName`: $($_.Exception.Message)"
        throw
    }
}

# Check Azure CLI login
Write-Host "Checking Azure CLI login..." -ForegroundColor Yellow
try {
    $CurrentUser = (az account show --query user.name -o tsv)
    if (-not $CurrentUser) {
        throw "Not logged in"
    }
    Write-Host "✅ Logged in as: $CurrentUser" -ForegroundColor Green
}
catch {
    Write-Error "❌ Please login to Azure CLI first: az login"
    exit 1
}

# Create resources for each environment
foreach ($Environment in $Environments) {
    Write-Host ""
    Write-Host "🔧 Setting up $Environment environment" -ForegroundColor Magenta
    Write-Host "================================" -ForegroundColor Yellow
    
    try {
        # Create storage account
        New-StorageAccount -Environment $Environment -ResourceGroup $ResourceGroup -Location $Location -ServicePrincipalObjectId $ServicePrincipalObjectId
        
        # Create key vault
        New-KeyVault -Environment $Environment -ResourceGroup $ResourceGroup -Location $Location -ServicePrincipalObjectId $ServicePrincipalObjectId
        
        Write-Host "✅ $Environment environment setup completed" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to setup $Environment environment: $($_.Exception.Message)"
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 All infrastructure setup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Created resources:" -ForegroundColor Yellow
Write-Host "=================="
foreach ($Environment in $Environments) {
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host "  - Storage Account: stdluk$Environment"
    Write-Host "  - Key Vault: kv-$Environment-dbws"
    Write-Host "  - Container: $($ContainerMap[$Environment])"
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "==========="
Write-Host "1. Push code to GitHub to trigger CI/CD"
Write-Host "2. Set up GitHub environment secrets"
Write-Host "3. Run Unity Catalog bootstrap notebook"
Write-Host "4. Test ELT pipeline"

Write-Host ""
Write-Host "📋 GitHub Secrets to configure:" -ForegroundColor Yellow
Write-Host "  - ARM_CLIENT_ID: <your-service-principal-client-id>"
Write-Host "  - ARM_CLIENT_SECRET: <your-service-principal-secret>"
Write-Host "  - ARM_TENANT_ID: <your-azure-tenant-id>"
Write-Host "  - ARM_SUBSCRIPTION_ID: <your-azure-subscription-id>"
Write-Host "  - GITHUB_TOKEN: <your-github-pat-token>"