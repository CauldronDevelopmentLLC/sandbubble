# sbx TODO

Features discussed but not yet implemented.

## Security primitives

### cwd blacklist
Refuse to run a sandbox whose cwd is bound from a sensitive host path. Override
with `--force-cwd`. Wrinkle: cwd handling is a property of the `bind` action
(`cwd: true`), not a top-level concept. The check belongs inside `action_bind`
when `cwd: true` is set. Must `realpath`-resolve before comparing to the
blacklist, and must catch ancestry (cwd inside a blacklisted dir, not just
exact match).

Default blacklist: `$HOME`, `$HOME/.ssh`, `$HOME/.gnupg`, `$HOME/.aws`,
`$HOME/.config`, `$HOME/.local`, `$HOME/Documents`, `$HOME/Desktop`,
`$HOME/Downloads`, `/`, `/etc`, `/root`.

### Per-sandbox network policy
Domain allowlist for outbound network. bwrap can't filter by domain; needs a
proxy in the parent namespace that the sandbox is routed through. Look at
how Docker's sbx does this.

### readonly-overlay action
Bind a host path read-only with a writable tmpfs upper layer. Writes go to
the overlay and are discarded on sandbox exit. Solves vscode extensions, npm
cache poisoning, pip cache poisoning, language server binaries. bwrap supports
this via `--overlay-src` / `--overlay`.

## Rules library

### Credential rules
Selective auth binds, one rule per tool. Each binds only the credential
file(s) that tool needs, nothing else.

- `claude-creds` - `~/.claude/.credentials.json`
- `gh-creds` - `~/.config/gh/hosts.yml`
- `npm-creds` - `~/.npmrc`
- `pip-creds` - `~/.pypirc`
- `aws-creds` - `~/.aws/credentials`, `~/.aws/config`
- `cargo-creds` - `~/.cargo/credentials.toml`

### vscode-shared rule
Shared read-only `~/.vscode/extensions` via `--extensions-dir`, per-sandbox
writable `--user-data-dir` under `$SANDBOX_HOME/.vscode-user`. Avoids
re-installing extensions per sandbox.

### Shared cache rules
Read-only binds of `~/.npm`, `~/.cache/pip`, `~/.cargo/registry`. Reduces
repeated downloads. Consider readonly-overlay variants for cases where the
tool needs to think it can write.

## Host-side

### sbx install-shims / uninstall-shims
Drop symlinks in `~/.local/bin/sbx-shims/` named after blocked tools (`npm`,
`npx`, `pip`, `pip3`, `pipx`, `node`, `cargo`, `code`, etc). Each symlink
points to the sbx binary itself.

sbx detects shim mode via `os.path.basename(os.path.dirname(sys.argv[0])) == 'shims'`.
In shim mode:
- If `SANDBOX` env var is set (already inside a sandbox), find the real
  binary via `which -a` excluding the shim dir and exec it.
- Otherwise, refuse with a message suggesting `sbx run`. Honor `SBX_BYPASS=1`
  as an escape hatch that execs the real binary.

Tool list configurable in `~/.config/sbx/shims.yml`.

## Worktree workflow

### Worktree pre-hook (not a built-in action)
A template ships a `pre-hook` script that creates a `git worktree`, and a
`delete-hook` (or `post-hook`) that removes it. Verify the existing hook
support is sufficient for this; if not, fix it.

This is the `claude-worktree` template that motivates parallel Claude
sessions on one repo. Worth building and shipping as a reference template
once the security primitives are in place.

## Other

### Shared credential access via pre-hook
The general pattern: pre-hook copies/decrypts credentials from a host vault
(pass, 1password, plain file, whatever) into `$SANDBOX_HOME` before bwrap
starts. No sbx changes needed - just document the pattern with examples.
