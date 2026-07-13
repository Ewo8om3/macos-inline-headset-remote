# Security policy

## Supported versions

Security fixes are applied to the latest released version and the default branch. Older releases may not receive backports.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could cause unexpected keystrokes, unsafe configuration replacement, command execution, privilege abuse, secret exposure, or bypass of device-collision safeguards.

Use GitHub's private vulnerability reporting for this repository. Open the repository's **Security** tab, choose **Report a vulnerability**, and include:

- the affected version or commit;
- the macOS and Karabiner-Elements versions;
- a minimal reproduction;
- the impact and required preconditions;
- sanitized logs or fixture data;
- any proposed mitigation.

If private vulnerability reporting is unavailable, contact the maintainer through the private contact method listed on their GitHub profile and ask for a secure reporting channel. Do not include exploit details in the initial public message.

You should receive an acknowledgment within seven days. Timing for a fix or disclosure depends on severity and reproducibility. Please allow a reasonable remediation window before public disclosure.

## Scope

Security-relevant areas include:

- unsafe edits or restore behavior affecting `karabiner.json`;
- backup disclosure or permissions;
- generic-device collision gates;
- preset or manifest validation bypasses;
- unintended shell command execution;
- symlink, path traversal, or temporary-file attacks;
- misleading dry-run behavior;
- removal of configuration not owned by the toolkit.

Karabiner-Elements and Wispr Flow are third-party projects. Report vulnerabilities in those applications to their maintainers unless this toolkit creates or amplifies the issue.

## Sensitive diagnostic data

Do not send a complete Karabiner configuration or backup unless explicitly requested through a private channel. These files may contain custom rules, application identifiers, device identifiers, or machine-specific preferences. Never include credentials, transcripts, microphone recordings, or account data.
