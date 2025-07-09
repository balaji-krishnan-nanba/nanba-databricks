# Nanba Databricks

Azure Databricks infrastructure with Unity Catalog, CI/CD pipelines, and ELT demo.

## 🚀 Quick Start

### Prerequisites

- Azure subscription with service principal configured
- GitHub repository with PAT (admin scopes)
- Databricks workspaces (dev/test/prod) with Unity Catalog enabled
- Azure CLI, Databricks CLI, and GitHub CLI installed

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/balaji-krishnan-nanba/nanba-databricks.git
   cd nanba-databricks
   ```

2. **Configure GitHub secrets**
   Set the following secrets in your GitHub repository settings:
   - `ARM_CLIENT_ID`: Service principal application ID
   - `ARM_CLIENT_SECRET`: Service principal secret
   - `ARM_TENANT_ID`: Azure tenant ID
   - `ARM_SUBSCRIPTION_ID`: Azure subscription ID
   - `GITHUB_TOKEN`: GitHub PAT with admin scopes

3. **Deploy infrastructure**
   ```bash
   # Using the setup script (Bash)
   chmod +x scripts/setup-infrastructure.sh
   ./scripts/setup-infrastructure.sh

   # OR using PowerShell
   PowerShell -ExecutionPolicy Bypass -File scripts/setup-infrastructure.ps1
   ```

4. **Push to trigger CI/CD**
   ```bash
   git add .
   git commit -m "Initial setup"
   git push origin main
   ```

## 📦 Repository Structure

```
.
├── .github/
│   └── workflows/          # CI/CD pipelines
├── docs/                   # Documentation
├── scripts/                # Infrastructure setup scripts
├── src/
│   └── notebooks/         # Databricks notebooks
├── bundle.yml             # Databricks Asset Bundle
└── README.md
```

## 🔄 CI/CD Workflow

### Automated Deployments

1. **Feature Development**: Create feature branch → Make changes → Open PR
2. **CI Pipeline**: Runs on PR (lint, test, validate)
3. **Dev Deployment**: Automatic on merge to main
4. **Test Deployment**: Manual trigger with approval
5. **Prod Deployment**: Manual trigger with 2 approvals

### Manual Deployment Commands

To deploy to test environment:
```bash
# Comment on PR or issue:
Deploy to test
```

To deploy to production:
```bash
# Comment on PR or issue:
Deploy to prod
```

## 🔐 Security

### PAT Auto-Generation

The CI/CD pipelines automatically generate and rotate Databricks PATs using the Token Management API:
- PATs are generated per environment
- 15-day lifetime (1,296,000 seconds)
- Stored as GitHub environment secrets
- No manual PAT management required

### Service Principal Permissions

The service principal has:
- Storage Blob Data Contributor on storage accounts
- Key Vault Secrets User on key vaults
- Account admin on Databricks metastore

## 📊 Unity Catalog Structure

```
Metastore (shared)
├── nanba_dev_bronze (catalog)
│   └── default (schema)
│       ├── orders_raw
│       ├── orders_curated
│       └── orders_agg
├── nanba_test_silver (catalog)
│   └── default (schema)
│       └── [same tables]
└── nanba_prod_gold (catalog)
    └── default (schema)
        └── [same tables]
```

## 🛠️ Maintenance

### Update Dependencies

```bash
# Update Python dependencies
pip install --upgrade databricks-cli

# Update GitHub Actions
# Edit version numbers in .github/workflows/*.yml
```

### Monitor Jobs

Access Databricks workspace → Workflows → View job runs

### Troubleshooting

1. **PAT generation fails**: Check service principal permissions
2. **Deployment fails**: Verify GitHub secrets are set correctly
3. **Job timeout**: Adjust timeout_seconds in bundle.yml

## 📝 License

This project is proprietary to Nanba Corporation.

## 🤝 Contributing

1. Create feature branch from main
2. Make changes
3. Submit PR with description
4. Wait for CI checks and approval
5. Merge using squash commits

## 📧 Support

For issues or questions:
- Create GitHub issue
- Contact: balaji.krishnan@nanba.com