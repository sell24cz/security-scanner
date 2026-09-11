# Public distribution changes

- Removed the original ASN; configuration is now explicit in local `config/asn.txt`.
- Excluded backup scripts, local configuration and all generated data.
- Translated script messages and email text to English.
- Removed workflow credential bindings, instance/workflow identifiers and webhook IDs; regenerated node IDs.
- Replaced email addresses with `example.com` placeholders.
- Replaced the deployment schedule with an inactive manual-trigger workflow.
- Required an exact completed scan ID for summary generation; updated the workflow command and sudoers example.
- Validated IDs and single-host IPv4 input before using values in paths or commands.
- Added workflow validation for missing counters and mismatched attachment paths.
- Added libpcap build/runtime dependencies to the Dockerfile.
- Retained Naabu rate 3000 and the original scanning parameters.

Validation performed locally: Bash syntax, malformed-ID rejection, report counts with synthetic documentation IPs, completed-run selection despite a newer running directory, and running-report rejection. No real network scan or email was sent during these checks. Docker image build and n8n execution remain unverified in this environment.
