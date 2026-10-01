# Maintenance contract

This is a sanitized standalone app repository. Never import private workbooks, bank statements, real snapshots, source manifests, personal paths, account IDs, screenshots, or populated app bundles. Private repository visibility does not permit private financial data in commits.

Build entrypoint: `python3 src/macapp/build.py`; outputs build/ and src/macapp/.cache/ are ignored. Build must not read any external ledger or bundle seed.json. Fresh launch is empty. Models.swift owns calculations/persistence, Views.swift owns page layout, Charts.swift owns hover overlays, main.swift owns lifecycle and fictitious fixtures. Existing local saved JSON stays local and wins over empty initial state.

Before committing: run tools/check_privacy.py after staging, inspect the staged diff, run build/self-test and relevant integration tests. New tracked paths require deliberate review and updates to the allowlists in .gitignore and tools/check_privacy.py. Do not use git add -f for data. Do not include private values in commit messages.
