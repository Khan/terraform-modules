# Contributing to Terraform Modules

## Development Workflow

1. Fork and clone the repository
2. Create a feature branch from `main`
3. Make your changes to modules in `terraform/modules/`
4. Submit a pull request

## Releases

Releases are created manually using the **Manual Release** GitHub Action:

1. Go to Actions → Manual Release
2. Select the module name (e.g., `scheduled-function`)
3. Enter version number (e.g., `1.0.0`) 
4. Add optional release notes in the text field
5. Run the workflow

### Release Notes

Release notes are added through the workflow input field and support markdown formatting. Include:

```markdown
## What's Changed
- New feature: Description of new functionality
- Bug fix: Description of what was fixed
- Breaking change: Description of breaking changes

## Upgrade Notes
- Any special instructions for upgrading
- Migration steps if needed
```

The workflow automatically adds usage instructions to every release.
