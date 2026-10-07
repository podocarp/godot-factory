# opencode CLI — Setup & Non-Interactive Usage (verified on this host)

Status: **WORKING** — verified 2026-10-08 with actual non-interactive runs (text reply + autonomous file write + session continuation).

## Install status

- Installed: `/etc/profiles/per-user/hermes/bin/opencode` (on PATH)
- Version: `opencode --version` → **1.18.32**
- No install step needed on this host. If it were missing:
  `nix profile install --extra-experimental-features 'nix-command flakes' nixpkgs#opencode`

## Credentials / provider config

- `~/.config/opencode/opencode.jsonc` exists but is minimal (only `{"$schema": ...}` — no provider overrides).
- `opencode auth list` → **0 stored credentials**; no provider API-key env vars are set
  (checked: OPENAI, ANTHROPIC, OPENROUTER, GEMINI/GOOGLE, XAI, DEEPSEEK, GROQ, MISTRAL,
  MOONSHOT, DASHSCOPE, GITHUB_TOKEN, etc. — all unset).
- Despite that, `opencode run` works out of the box via the built-in **`opencode/` free-model
  provider** (no auth required, outbound HTTPS confirmed). Default model: `opencode/big-pickle`.
- Available models (`opencode models`, 11 total, all `opencode/` free tier):
  `big-pickle` (default), `exo-free`, `fledge-alpha-free`, `ling-3.0-flash-fin-free`,
  `ling-3.1-flash-free`, `longcat-2.5-preview-free`, `mimo-v2.6-flash-free`,
  `muse-spark-1.3-contributor-free`, `nemotron-3-ultra-free`, `nemotron-3.5-lightning-free`,
  `space-bunny-free`.
- To use a paid provider later: `opencode auth login` (interactive) or export the provider's
  `*_API_KEY` before invoking.

## Working non-interactive command template

```bash
cd <repo-dir>                      # opencode operates on its CWD
opencode run [--auto] [-m provider/model] '<prompt>'
```

Verified flags (from `opencode run --help`):

| Flag | Meaning |
|---|---|
| `-m, --model provider/model` | e.g. `-m opencode/big-pickle` (default model works without it) |
| `--auto` | auto-approve permissions not explicitly denied (dangerous!) |
| `-c, --continue` / `-s, --session <id>` | continue a previous session (verified working) |
| `--fork` | fork session before continuing (needs `-c`/`-s`) |
| `-f, --file <path>` | attach file(s) to the message (repeatable) |
| `--format json` | raw JSON events (machine-parseable) instead of formatted text |
| `--dir <path>` | run in a directory (path on remote server when using `--attach`) |
| `--agent <name>` | select an agent |
| `--variant <effort>` | provider reasoning-effort variant |
| `--print-logs`, `--log-level` | diagnostics to stderr |
| `--attach http://localhost:PORT` | attach to a running `opencode serve` instance |

Notes:
- Prompt can also be piped via stdin: `echo 'prompt' | opencode run` (verified).
- For a prompt stored in a file: `opencode run "$(cat prompt.txt)"` or attach it with `-f prompt.txt`.
- Exit code 0 on success; output goes to stdout.

## Permissions / auto-approve behavior

- `--auto` auto-approves any permission not explicitly denied.
- **Observed on this host:** in non-interactive `run` mode, a plain file *write* inside the CWD
  was approved and executed **without** `--auto` (edit tool allowed by default for the free
  `build` agent). Deny/ask rules can be set per-project in `opencode.json` under a `"permission"`
  key (see https://opencode.ai/docs/permissions). For unattended automation, pass `--auto`
  anyway so nothing can stall on a prompt, and constrain the CWD to the repo.

## Copy-paste example: have opencode write a small file in a repo

```bash
cd /persist/hermes/workspace/godot-factory
opencode run --auto -m opencode/big-pickle \
  'Create docs/opencode-smoketest.md containing exactly one line: opencode works'
cat docs/opencode-smoketest.md
```

Equivalent run performed during verification (throwaway dir
`~/.hermes/profiles/gamedev/cache/scratch/oc-test`):

```
$ opencode run --auto -m opencode/big-pickle 'Create a file named hello.txt containing exactly the text: opencode works'
> build · big-pickle
← Write hello.txt
Wrote file successfully.
Done
$ cat hello.txt
opencode works
```

## Gotchas

- Free-tier models only, unless the user adds credentials (`opencode auth login` or `*_API_KEY`
  env var). Quality/rate limits of the free `opencode/*` models are not guaranteed.
- opencode resolves the repo from its **CWD** (or `--dir`); always `cd` into the target repo first.
- Sessions are persisted per directory; `-c` continues the last session in that dir (verified).
- `--auto` is flagged dangerous by the CLI itself — scope it to trusted repos only.
