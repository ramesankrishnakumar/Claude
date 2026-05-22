# Troubleshooting

## "gws: command not found"

The `gws` CLI is required. Check if it's installed:
```bash
which gws
```

## 401 / 403 Authentication Errors

Re-authenticate:
```bash
gcloud auth login
```

`gws` picks up credentials automatically via its keyring backend.

## "Request had insufficient authentication scopes"

The `gcloud auth login` session may not include Docs/Drive scopes. Try:
```bash
gcloud auth application-default login \
  --scopes="https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/drive"
```

## "invalid_grant" or "Token has been revoked"

```bash
gcloud auth revoke
gcloud auth login
```

## "The caller does not have permission"

- Verify Google account has access to the document
- Shared documents require edit permissions

## gws --upload path error

`gws --upload` requires files to be under the current working directory. The scripts handle this automatically by writing temp files to cwd. If you see path errors, ensure you're running from a writable directory.

## "Using keyring backend: keyring" in output

This is a normal `gws` informational message on stderr. The scripts filter it out automatically.
