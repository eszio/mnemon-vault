# Contributing

## Development setup

```bash
git clone <this-repo> ~/mnemon-vault-dev
cd ~/mnemon-vault-dev
```

No build step — the main script is plain bash.

## Linting

```bash
shellcheck mnemon-vault install.sh
```

All warnings must be clean before submitting a PR. SC2006, SC2015, and SC2001 are treated as errors.

## Testing manually

```bash
# Check your git host config
./mnemon-vault configure

# Verify keys are fetched
./mnemon-vault keygen

# Dry-run push (requires mnemon installed with data)
./mnemon-vault status
```

## Pull requests

- One feature or fix per PR
- `shellcheck` must pass
- Update `README.md` if behaviour changes
- Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `chore:`, `docs:`

## Security

- Do not add hardcoded credentials, URLs, or hostnames to the script
- Per-machine config belongs in `~/.config/mnemon-vault/config` only
- Encryption logic must not be weakened — age + SSH public keys is the contract

## Reporting issues

Open a GitHub issue. For security vulnerabilities, email the maintainer directly instead of opening a public issue.
