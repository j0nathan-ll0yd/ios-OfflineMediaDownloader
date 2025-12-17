# Git Workflow

## Quick Reference
- **When to use**: All commits and branches
- **Enforcement**: Required
- **Impact if violated**: Medium - Commit history quality

---

## Conventional Commits

Use the Conventional Commits format for all commit messages:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(login): add Sign in with Apple` |
| `fix` | Bug fix | `fix(download): handle cancelled downloads` |
| `refactor` | Code refactoring | `refactor(FileList): extract FileCellFeature` |
| `docs` | Documentation | `docs: update AGENTS.md conventions` |
| `test` | Tests | `test(LoginFeature): add auth flow tests` |
| `chore` | Maintenance | `chore: update TCA to 1.22.2` |
| `style` | Formatting | `style: fix indentation in views` |

### Scopes

Common scopes for this project:

| Scope | Area |
|-------|------|
| `login` | LoginFeature, authentication |
| `files` | FileListFeature, FileCellFeature |
| `download` | DownloadClient, file downloads |
| `keychain` | KeychainClient, Valet storage |
| `api` | ServerClient, network calls |
| `coredata` | CoreDataClient, persistence |
| `root` | RootFeature, app entry |
| `diagnostic` | DiagnosticFeature, debug tools |

### Examples

```bash
# Feature
feat(files): add pull-to-refresh support

# Bug fix
fix(download): cancel active downloads when file deleted

# Refactor
refactor(login): migrate from auth code to ID token flow

# Documentation
docs(wiki): add TCA reducer patterns

# Test
test(FileListFeature): verify state preservation on refresh
```

---

## Branch Naming

### Format
```
<type>/<short-description>
```

### Types
- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation updates

### Examples
```
feature/background-downloads
fix/auth-token-expiry
refactor/dependency-injection
docs/agents-md-update
```

---

## Pull Request Guidelines

### PR Title
Follow the same Conventional Commits format:
```
feat(files): implement background download support
```

### PR Description Template
```markdown
## Summary
Brief description of changes

## Changes
- List of specific changes
- Another change

## Testing
- How was this tested?
- Any manual testing steps?

## Screenshots
(if applicable)
```

---

## Git Workflow

### Feature Development
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and commit
git add .
git commit -m "feat(scope): description"

# Push and create PR
git push -u origin feature/new-feature
```

### Keeping Branch Updated
```bash
# Fetch latest main
git fetch origin main

# Rebase on main
git rebase origin/main

# Force push if needed (only on feature branches)
git push --force-with-lease
```

---

## Rationale

- **Conventional Commits**: Enables automatic changelog generation and semantic versioning
- **Descriptive scopes**: Makes commit history searchable by feature area
- **Branch naming**: Quick identification of branch purpose

---

## Related Patterns
- [Documentation-Patterns.md](../Meta/Documentation-Patterns.md)
