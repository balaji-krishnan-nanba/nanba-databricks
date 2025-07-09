# Branching Strategy

## Trunk-Based Development

This project follows a trunk-based development model with the following principles:

### Branch Types

1. **main** (trunk)
   - The primary branch
   - Always deployable
   - Protected with branch rules
   - Direct commits not allowed

2. **feature/** branches
   - Short-lived (max 2-3 days)
   - Created from main
   - Merged back via PR
   - Deleted after merge

### Workflow

```
main ────────────────────────────────────────────────▶
  │         │         │         │
  └─feature/│         │         │
    add-api │         │         │
      │     │         │         │
      └─────┘         │         │
            └─feature/│         │
              fix-bug │         │
                │     │         │
                └─────┘         │
                      └─feature/│
                        update  │
                          │     │
                          └─────┘
```

### Best Practices

1. **Keep branches short-lived**
   - Maximum 2-3 days per feature branch
   - If longer needed, break into smaller features

2. **Pull Request Guidelines**
   - Clear, descriptive title
   - Link to issue if applicable
   - Must pass all CI checks
   - Requires approval from Balaji-Krishnan-Nanba

3. **Commit Messages**
   - Use conventional commits format
   - Examples:
     ```
     feat: add customer metrics to gold layer
     fix: correct aggregation logic in ELT pipeline
     docs: update deployment instructions
     chore: update databricks CLI version
     ```

4. **Merge Strategy**
   - Squash and merge only
   - Maintains linear history
   - Easier to track changes

### Branch Protection Rules

The `main` branch has the following protections:

1. **Required Reviews**
   - At least 1 approval required
   - Approval from Balaji-Krishnan-Nanba required
   - Dismiss stale reviews on new commits

2. **Status Checks**
   - CI pipeline must pass
   - Bundle validation must succeed

3. **Merge Requirements**
   - Must be up to date with main
   - Squash merging enforced
   - Auto-delete head branches

4. **Additional Rules**
   - No force pushes allowed
   - No branch deletion allowed
   - Administrators included in restrictions

### Common Scenarios

#### Creating a Feature Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/add-new-table
```

#### Keeping Branch Updated
```bash
git checkout feature/add-new-table
git fetch origin
git rebase origin/main
```

#### Creating a Pull Request
```bash
git push origin feature/add-new-table
# Then create PR via GitHub UI or CLI
gh pr create --title "Add new table to catalog" --body "Description here"
```

#### After PR Merge
The feature branch is automatically deleted. Pull latest main:
```bash
git checkout main
git pull origin main
```

### Anti-Patterns to Avoid

1. ❌ Long-lived feature branches
2. ❌ Merging main into feature branches (use rebase instead)
3. ❌ Direct commits to main
4. ❌ Creating branches from other feature branches
5. ❌ Keeping stale branches around

### Release Process

Since we follow trunk-based development:
- Every merge to main triggers dev deployment
- Test deployments are triggered manually
- Prod deployments require additional approval
- No separate release branches needed

### Hotfix Process

For urgent production fixes:
1. Create branch from main: `feature/hotfix-description`
2. Make minimal changes
3. Fast-track PR review
4. Deploy through normal pipeline