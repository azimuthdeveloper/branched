# 11 — Authentication

## Overview

Authentication is critical for remote Git operations (clone, fetch, pull, push). Furcate must support SSH keys, HTTPS credentials, and integration with system credential stores — all handled through git2dart's credential callback system.

---

## Authentication Methods

### 1. SSH Key Authentication

| Method | Description | Implementation |
|--------|-------------|----------------|
| SSH Key File | Standard `~/.ssh/id_rsa` or `~/.ssh/id_ed25519` | `git2dart` `Keypair` credential |
| SSH Agent | System ssh-agent / Pageant (Windows) | `git2dart` `KeypairFromAgent` |
| SSH Key with Passphrase | Encrypted private key | `Keypair` + passphrase prompt |
| Custom Key Path | User-specified key location | `Keypair` with custom paths |

### 2. HTTPS Authentication

| Method | Description | Implementation |
|--------|-------------|----------------|
| Username + Password | Basic HTTP auth | `git2dart` `UserPass` credential |
| Personal Access Token (PAT) | Token as password | `UserPass` with token as password |
| OAuth Token | GitHub/GitLab OAuth | `UserPass` with token |

### 3. System Credential Stores

| Platform | Credential Store | Integration |
|----------|-----------------|-------------|
| macOS | Keychain | `flutter_secure_storage` or direct Keychain API |
| Linux | GNOME Keyring / KWallet / Secret Service | `flutter_secure_storage` (uses libsecret) |
| Windows | Windows Credential Manager | `flutter_secure_storage` (uses WinCred) |

---

## Credential Callback Flow

```
1. Remote operation initiated (fetch/pull/push/clone)
2. git2dart calls credential callback
3. Callback receives: url, username_from_url, allowed_types
4. GitAuthHandler determines credential type needed:

   If SSH URL (git@...):
     a. Try ssh-agent first (KeypairFromAgent)
     b. If agent fails: try default key paths (~/.ssh/id_ed25519, id_rsa)
     c. If key needs passphrase: prompt user
     d. If no key found: prompt user for key file path

   If HTTPS URL (https://...):
     a. Check stored credentials for this host
     b. If found: use stored credentials
     c. If not found: prompt user for username + password/token
     d. If stored credentials fail: prompt again (max 3 retries)

5. Return credential to git2dart
6. If auth succeeds: optionally save credentials to secure storage
7. If auth fails: git2dart calls callback again (up to max retries)
```

---

## Credential Prompt Dialog

### HTTPS Credential Dialog

```
┌──────────────────────────────────────────┐
│  Authentication Required            [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  Remote: origin (github.com)             │
│  Protocol: HTTPS                         │
│                                          │
│  Username:                               │
│  ┌──────────────────────────────────┐    │
│  │ username                          │    │
│  └──────────────────────────────────┘    │
│                                          │
│  Password / Token:                       │
│  ┌──────────────────────────────────┐    │
│  │ ••••••••••••                      │    │
│  └──────────────────────────────────┘    │
│                                          │
│  [✓] Save credentials securely           │
│                                          │
│  💡 For GitHub, use a Personal Access    │
│     Token instead of your password.      │
│                                          │
│              [ Cancel ]  [ Sign In ]     │
└──────────────────────────────────────────┘
```

### SSH Passphrase Dialog

```
┌──────────────────────────────────────────┐
│  SSH Key Passphrase                 [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  Key: ~/.ssh/id_ed25519                  │
│                                          │
│  Passphrase:                             │
│  ┌──────────────────────────────────┐    │
│  │ ••••••••••••                      │    │
│  └──────────────────────────────────┘    │
│                                          │
│  [✓] Remember passphrase                 │
│                                          │
│              [ Cancel ]  [ Unlock ]      │
└──────────────────────────────────────────┘
```

### SSH Key Selection Dialog

```
┌──────────────────────────────────────────┐
│  SSH Key Not Found                  [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  No default SSH key found.               │
│  Select a private key file:              │
│                                          │
│  ┌──────────────────────────┐ [Browse]   │
│  │ /home/user/.ssh/custom_key │           │
│  └──────────────────────────┘            │
│                                          │
│              [ Cancel ]  [ Use Key ]     │
└──────────────────────────────────────────┘
```

---

## GitAuthHandler

The `GitAuthHandler` is a singleton service that manages the entire authentication lifecycle.

### Responsibilities

| Responsibility | Description |
|---------------|-------------|
| Credential resolution | Determine which credential type to use based on URL and allowed types |
| Credential caching | Keep credentials in memory for the session |
| Secure storage | Read/write credentials to platform keychain |
| User prompting | Show dialogs to collect credentials |
| Retry management | Track retry count, prevent infinite auth loops |
| SSH key discovery | Scan `~/.ssh/` for available keys |

### Default SSH Key Discovery Order

```
1. ~/.ssh/id_ed25519     (Ed25519 — preferred)
2. ~/.ssh/id_ecdsa       (ECDSA)
3. ~/.ssh/id_rsa         (RSA)
4. ~/.ssh/id_dsa         (DSA — legacy)
```

For each: check if corresponding `.pub` file exists.

### Credential Storage Schema

Store credentials per-host in secure storage:

```
Key:    "furcate_cred_github.com"
Value:  {
  "type": "https",           // "https" or "ssh"
  "username": "octocat",
  "password": "ghp_xxxxx",   // encrypted at rest by OS keychain
  "host": "github.com",
  "lastUsed": "2025-01-15T12:00:00Z"
}

Key:    "furcate_ssh_github.com"
Value:  {
  "type": "ssh",
  "keyPath": "/home/user/.ssh/id_ed25519",
  "passphrase": "encrypted_passphrase",   // optional
  "host": "github.com",
  "lastUsed": "2025-01-15T12:00:00Z"
}
```

---

## SSH Configuration

### SSH Config File Parsing

Parse `~/.ssh/config` to resolve host-specific settings:

```
# ~/.ssh/config
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_ed25519

Host work
  HostName gitlab.company.com
  User git
  IdentityFile ~/.ssh/work_key
  Port 2222
```

**Parsed fields:**
- `HostName`: actual host to connect to
- `IdentityFile`: which SSH key to use
- `Port`: custom SSH port
- `User`: SSH username

### SSH Known Hosts

- On first connection to a new host: show host key fingerprint
- Ask user to verify and add to `~/.ssh/known_hosts`
- On host key mismatch: show warning with old vs. new fingerprint

```
┌──────────────────────────────────────────┐
│  ⚠ Unknown SSH Host                [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  The authenticity of host                │
│  'github.com' can't be established.      │
│                                          │
│  ED25519 key fingerprint:               │
│  SHA256:+DiY3wvvV6TuJJhbpZisF/...       │
│                                          │
│  Add to known hosts?                     │
│                                          │
│  [ Cancel ]  [ Add and Continue ]        │
└──────────────────────────────────────────┘
```

---

## Credential Management UI (Settings)

```
┌──────────────────────────────────────────────────────┐
│  Saved Credentials                                    │
├──────────────────────────────────────────────────────┤
│                                                       │
│  github.com                                           │
│    HTTPS: octocat (PAT)              [ Edit ] [🗑]   │
│    SSH: ~/.ssh/id_ed25519            [ Edit ] [🗑]   │
│                                                       │
│  gitlab.company.com                                   │
│    HTTPS: john.doe                   [ Edit ] [🗑]   │
│                                                       │
│  [ Add Credential ]  [ Clear All ]                    │
└──────────────────────────────────────────────────────┘
```

---

## Security Considerations

| Concern | Mitigation |
|---------|------------|
| Credentials in memory | Clear from memory after use; use `SecureString` if available |
| Credentials at rest | Use OS keychain (Keychain, Credential Manager, Secret Service) |
| Passphrase exposure | Never log passphrases; show as dots in UI |
| Token scope | Guide users to create tokens with minimal required scopes |
| SSH agent forwarding | Support but don't enable by default |
| Credential prompt spam | Max 3 retries before showing "Auth failed" error |
| MITM attacks | Verify SSH host keys; enforce HTTPS certificate validation |

---

## Platform-Specific Notes

### macOS
- Use Keychain Services for credential storage
- SSH agent (`ssh-agent`) is typically running via Keychain
- Passphrase can be stored in Keychain via `ssh-add --apple-use-keychain`

### Linux
- Use Secret Service API (GNOME Keyring / KWallet)
- `ssh-agent` must be explicitly started
- Some users may use `gpg-agent` for SSH

### Windows
- Use Windows Credential Manager
- Pageant (PuTTY's SSH agent) support
- OpenSSH agent (available in modern Windows)
- May need to handle PuTTY `.ppk` key format conversion

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Two-factor auth (GitHub) | PAT is required; guide user to create one |
| Expired token | Detect 401, prompt for new token |
| Corporate proxy | Detect proxy from system settings, pass to libgit2 |
| Self-signed certificates | Option to skip certificate validation (with warning) |
| SSH key not readable | Show permission error, suggest `chmod 600` |
| Multiple keys for same host | Let user choose via SSH config or manual selection |
| Credential store unavailable | Fall back to in-memory only (session-scoped) |
