# Architecture Overview

## CI/CD Pipeline Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  feature/*      │     │     main        │     │   Deployments   │
│   branches      │────▶│    (trunk)      │────▶│                 │
└─────────────────┘ PR  └─────────────────┘     └─────────────────┘
        │                        │                        │
        │                        │                        │
        ▼                        ▼                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   CI Pipeline   │     │  Auto-deploy    │     │ Manual Approval │
│  - Lint         │     │   to DEV        │     │                 │
│  - Unit Test    │     │                 │     │  ┌───────────┐  │
│  - Validate     │     │ ┌─────────────┐ │     │  │   TEST    │  │
└─────────────────┘     │ │ DEV Env     │ │     │  │ (1 approver)│ │
                        │ │ - PAT Gen   │ │     │  └───────────┘  │
                        │ │ - Deploy    │ │     │                 │
                        │ └─────────────┘ │     │  ┌───────────┐  │
                        └─────────────────┘     │  │   PROD    │  │
                                                │  │(2 approvers)│ │
                                                │  └───────────┘  │
                                                └─────────────────┘
```

## Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                        │
├─────────────────────────────────────────────────────────────────┤
│                     Resource Group: nanba-github                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Storage     │  │  Storage     │  │  Storage     │          │
│  │  stdlukdev   │  │  stdluktest  │  │  stdlukprod  │          │
│  │  (Bronze)    │  │  (Silver)    │  │  (Gold)      │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                  │                  │                  │
│         │                  │                  │                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Key Vault   │  │  Key Vault   │  │  Key Vault   │          │
│  │ kv-dev-dbws  │  │ kv-test-dbws │  │ kv-prod-dbws │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Databricks Workspaces                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ databricks-  │  │ databricks-  │  │ databricks-  │          │
│  │ uksouth-dev  │  │ uksouth-test │  │ uksouth-prod │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                 │
│                            │                                     │
│                    ┌───────────────┐                             │
│                    │  Shared Unity  │                            │
│                    │   Metastore    │                            │
│                    └───────────────┘                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ELT Pipeline Flow                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────┐      ┌───────────────┐     ┌───────────────┐ │
│  │               │      │               │     │               │ │
│  │  Bronze Layer │ ───▶ │ Silver Layer  │ ──▶ │  Gold Layer   │ │
│  │  (Raw Data)   │      │  (Cleansed)   │     │ (Aggregated)  │ │
│  │               │      │               │     │               │ │
│  └───────────────┘      └───────────────┘     └───────────────┘ │
│         │                       │                      │         │
│         │                       │                      │         │
│  ┌───────────────┐      ┌───────────────┐     ┌───────────────┐ │
│  │ orders_raw    │      │orders_curated │     │  orders_agg   │ │
│  └───────────────┘      └───────────────┘     └───────────────┘ │
│                                                                  │
│  Scheduled: Daily @ 02:00 UTC                                   │
│  Timeout: 1 hour                                                │
│  Cluster: Single-node DBR 15.4 LTS                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Security Model                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Service Principal (Account Admin)                               │
│  ├── Storage Blob Data Contributor (all storage accounts)       │
│  ├── Key Vault Secrets User (all key vaults)                    │
│  └── Databricks Account Admin (metastore)                       │
│                                                                  │
│  GitHub Actions                                                  │
│  ├── Uses Service Principal for Azure auth                       │
│  ├── Generates temporary PATs (15 days)                         │
│  └── Stores PATs in GitHub env secrets                          │
│                                                                  │
│  Network Security                                                │
│  ├── Storage: Private endpoints + firewall                       │
│  ├── Key Vault: Private endpoints + firewall                    │
│  └── Databricks: VNet injection (optional)                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Sequence

```
1. Infrastructure Provisioning (one-time)
   ├── Run setup-infrastructure.sh or .ps1
   ├── Creates storage accounts (stdlukdev, stdluktest, stdlukprod)
   ├── Creates key vaults (kv-dev-dbws, kv-test-dbws, kv-prod-dbws)
   └── Configure permissions for service principal

2. CI Pipeline (on PR)
   ├── Lint Python notebooks
   ├── Run unit tests
   └── Validate bundle

3. CD Pipeline - Dev (on merge)
   ├── Generate PAT
   ├── Store in GitHub secret
   └── Deploy bundle

4. CD Pipeline - Test (manual)
   ├── Require approval
   ├── Generate PAT
   ├── Store in GitHub secret
   └── Deploy bundle

5. CD Pipeline - Prod (manual)
   ├── Require 2 approvals
   ├── Generate PAT
   ├── Store in GitHub secret
   └── Deploy bundle
```