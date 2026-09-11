# n8n integration

Import `n8n/security-scanner-full.json` through n8n's Import from File action. This export is adapted from the supplied workflow; credentials, deployment identifiers and the production schedule have been removed. It is inactive and uses a Manual Trigger. Bind an SSH private-key credential on all four SSH nodes and an SMTP credential on both email nodes. Replace both sender/recipient placeholders. The imported workflow has not yet been executed in n8n.

```text
Trigger -> SSH Start -> Parse scan ID -> Wait -> SSH Check -> Parse status
                                         ^                       |
                                         +-- STARTING/RUNNING ---+
                                                                 |
                       FAILED/NOT_FOUND/UNKNOWN -> error handling  |
                                                                 |
                         COMPLETED -> Parse counters -> SSH Summary
                                                           |
                                                  Download (binary data)
                                                           |
                                                       Send email
```

## Credentials and permissions

Create your own SSH credential targeting the scanner host and your own SMTP credential. Set sender and recipient explicitly. Credentials and infrastructure values must not be included in a public export.

An illustrative sudoers entry for a dedicated SSH account named `n8n-runner` is below. Install through `visudo` and validate with `visudo -c`; do not give this account write access to the scripts or their parent directory.

```sudoers
n8n-runner ALL=(root) NOPASSWD: /opt/security-scanner/scripts/start-full-scan.sh, /opt/security-scanner/scripts/check-full-scan.sh *, /opt/security-scanner/scripts/make-summary.sh *
```

The check/report scripts validate the scan ID. In this distribution, the summary script requires the ID; its sudoers entry therefore includes an argument. This example assumes the default fixed `/opt/security-scanner` installation path. Configure read-only access to result files separately for SSH downloads.

## Node commands and expressions

The example node names below are descriptive. Match references to the exact names in your workflow.

**Start FULL (SSH Execute):**

```bash
sudo /opt/security-scanner/scripts/start-full-scan.sh
```

It returns immediately. Do not keep the SSH node waiting for the entire scan.

**Scan ID (Edit Fields):** create `scan_id` from Start's stdout:

```javascript
{{ $json.stdout.match(/^SCAN_ID=([0-9]{8}_[0-9]{6})$/m)?.[1] }}
```

Reject missing/invalid IDs before constructing shell commands. Preserve this value through polling. Add a Wait node (for example, 60 seconds; this is a suggested interval, not a claimed production setting).

**Check FULL (SSH Execute):**

```javascript
sudo /opt/security-scanner/scripts/check-full-scan.sh {{ $('Scan ID').first().json.scan_id }}
```

**Status (Edit Fields):**

```javascript
{{ $json.stdout.match(/^STATUS=(\w+)$/m)?.[1] || 'UNKNOWN' }}
```

`STARTING` and `RUNNING` return to Wait. `COMPLETED` proceeds to reporting. `FAILED`, `NOT_FOUND`, `UNKNOWN` and SSH errors must enter an error branch. Nonzero SSH exits may bypass the status parser depending on node error settings; explicitly handle these too. Add a finite timeout or polling limit and investigate on expiry; do not leave an endless loop or automatically launch a duplicate scan.

**Report fields (Edit Fields):** parse the completed Check stdout:

```javascript
scan_id: {{ $json.stdout.match(/^SCAN_ID=([0-9]{8}_[0-9]{6})$/m)?.[1] }}
prefix_ips: {{ $json.stdout.match(/^PREFIX_IPS=(\d+)$/m)?.[1] }}
ports: {{ $json.stdout.match(/^PORTS=(\d+)$/m)?.[1] }}
http: {{ $json.stdout.match(/^HTTP=(\d+)$/m)?.[1] }}
critical: {{ $json.stdout.match(/^CRITICAL=(\d+)$/m)?.[1] }}
critical_list: {{ $json.stdout.match(/CRITICAL_LIST_BEGIN([\s\S]*?)CRITICAL_LIST_END/)?.[1]?.trim() }}
```

Each line above represents a separate field, not a single JSON object. The bundled export adds validation expressions that throw on a missing scan ID or counter instead of silently substituting zero. It also validates that the download path belongs to the same scan ID.

**Build summary (SSH Execute):**

```javascript
sudo /opt/security-scanner/scripts/make-summary.sh {{ $('Report fields').first().json.scan_id }}
```

Parse the path from its stdout:

```javascript
{{ $json.stdout.match(/^SUMMARY=(.+)$/m)?.[1]?.trim() }}
```

**Download summary (SSH Download):** use that absolute host path as the remote file path and store the file in the binary property `data`. This downloads the file contents; merely passing a path string does not attach a file.

**Send email:** configure the attachment field as `data`. Reference report values by node name, since the download node's current `$json` may not contain them:

```javascript
{{ 'FULL scan ' + $('Report fields').first().json.scan_id + ' — Critical: ' + $('Report fields').first().json.critical }}
```

Example plain-text body:

```text
Full scan completed.

SCAN ID: {{ $('Report fields').first().json.scan_id }}
IPv4 addresses in scope: {{ $('Report fields').first().json.prefix_ips }}
Open ports: {{ $('Report fields').first().json.ports }}
HTTP/HTTPS records: {{ $('Report fields').first().json.http }}
Critical matches: {{ $('Report fields').first().json.critical }}

{{ $('Report fields').first().json.critical_list }}

See the attached summary.txt.
```

## Before enabling the schedule

Configure your timezone/schedule, SSH and SMTP credentials and result-file permissions. Test with approved scope. Confirm that COMPLETED, FAILED and SSH error paths work, that the attachment belongs to the same ID, and that missing fields do not create an empty success email.

Keep the workflow inactive until configured. Remove pinned execution data, credentials references, production addresses and instance metadata before exporting publicly.

The export retains the original 30-minute Wait interval; the 60-second interval above is an optional example. Polling has no finite limit in the inherited graph: configure a workflow timeout/poll limit before unattended use. Transport errors and validation exceptions stop the execution; the Send error node handles returned scan-status errors, not every possible node failure. Configure a separate n8n error workflow if all failures must generate notifications.
