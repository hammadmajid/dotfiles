# Secrets: Infisical (self-hosted) with Doppler as the old copy

Every project's environment variables are backed up to the self-hosted Infisical at `https://secrets.kryft.dev` (org "Secrets Management", free plan). Doppler still holds the same values for its six projects and is left untouched as a fallback; nothing new goes there.

## Rule for Claude

Never read, print, grep or cat a secret value. Work file-to-file: Doppler and local `.env` files are copied into `$XDG_RUNTIME_DIR` (RAM, mode 600), Infisical reads them with `secrets set --file`, and comparisons go through `envdiff`, which prints key names and hash counts only. `infisical secrets set` masks values in its table by default; never pass `--show-values`.

## Where each project lives

| Infisical project | Source | Environments and folders |
|---|---|---|
| alfaqeer | Doppler `alfaqeer`, repo `alfaqeerfabrics.com` | dev, prod |
| classguard | Doppler `classguard`, repo `classguard.dev` | dev, prod, prod `/ci` (Doppler `ci` config) |
| fintraq | Doppler `fintraq`, repo `fintraq.tech` | dev, staging (Doppler `preview`), prod |
| hostgrid | Doppler `hostgrid`, no repo here | dev, prod |
| Studio Pret | Doppler `pret`, repo `studio-pret.com` | dev, staging (Doppler `stg`), prod |
| sajjandera | Doppler `sajjandera`, repo `sajjandera.com` | dev only; Doppler prod was empty |
| prismark | local `.env` files, repo `prismark` | dev `/apps/native`, `/apps/server`, `/apps/web` |
| WowAI Tech | local `.env` files, repo `wowaitech.com` | dev `/apps/api`, `/apps/pocketbase`, `/apps/web` |

Doppler's `dev_personal` and `prd_personal` branches were identical to their root configs and were not migrated. Keys with empty values are not stored (Infisical rejects them); `envs diff` lists them. The `DOPPLER_*` marker keys are dropped on import.

Each repo has an `.infisical.json` in its root holding only the project id; commit it. Monorepos need `--path /apps/<name>` on `infisical run` and `infisical export`.

## Day to day

`envs` (fish) works on the repo containing the current directory:

| Command | Does |
|---|---|
| `envs push [env]` | push every `.env` (root -> `/`, `apps/x/.env` -> `/apps/x`) |
| `envs diff [env]` | compare local files with Infisical: same / differ / only-in, by key |
| `envs pull [env]` | overwrite local `.env` files from Infisical after a y/N, keeping `.env.bak` |
| `envs doppler <project> <config> [env] [path]` | import a Doppler config into this repo's project |
| `envs list` | show the file-to-path mapping |

`env` defaults to `dev`. New project: `infisical init` in the repo root (or create the project via the UI and write `.infisical.json` with its id), then `envs push`.

`INFISICAL_DOMAIN` is exported from `config.fish`, so `infisical` and `envs` talk to the self-hosted instance from any directory. `envdiff` lives in stow package `infisical` as `~/.local/bin/envdiff`.

## Gotchas found during migration (CLI 0.43.130 against server 0.165.8)

- `infisical secrets delete` fails against this server; delete with the API instead: `DELETE /api/v3/secrets/raw/<KEY>` with `workspaceId`, `environment`, `secretPath` in the JSON body, bearer token from `infisical user get token --plain`.
- The CLI has no project-list command; `GET /api/v1/workspace` with the same token lists them. `POST /api/v2/workspace` with `projectName`, `slug`, `type: secret-manager` creates one.
- `secrets set --file` aborts the whole file on the first empty value, hence the strip step in `envs`.
- Folders must exist before `--path` is used; `envs` creates each segment with `secrets folders create`.
