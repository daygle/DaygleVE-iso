# Security Policy

## Supported versions

Security fixes are made for the latest release and the `main` branch. Older
releases are supported on a best-effort basis; upgrading to the latest release
is recommended.

## Reporting a vulnerability

Please do not report security vulnerabilities in public GitHub issues,
discussions, or pull requests.

Use GitHub's private vulnerability reporting or Security Advisories for this
repository:

1. Open the repository's **Security** tab.
2. Select **Advisories**.
3. Choose **Report a vulnerability** and include the details below.

If private reporting is unavailable, open a new issue requesting a private
contact channel without including sensitive vulnerability details.

Please include, where possible:

- A clear description of the vulnerability and its impact.
- The affected component, file, version, or commit.
- Reproduction steps or a minimal proof of concept.
- Any required configuration, environment, or permissions.
- A suggested mitigation, if known.

Reports should not include passwords, access tokens, private keys, personal
data, or production data.

## Response and disclosure

We will acknowledge a report as soon as practical, investigate its impact,
and coordinate a fix or mitigation with the reporter. Please allow time for a
fix to be prepared before publicly disclosing the vulnerability.

When a fix is available, the project may publish a security advisory describing
the impact, affected versions, and upgrade guidance. Reporter credit will be
included only with permission.

## Scope

This policy covers the ISO build tooling and configuration in this repository,
including the build workflow, scripts, boot configuration, and files included
in the live image.

The backend, frontend, and schema repositories are separate projects. Issues
specific to those components should be reported through their respective
security policies.
