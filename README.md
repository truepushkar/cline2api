# cline2api

Cline's free models as an OpenAI/Anthropic-compatible API — deploy on
Cloudflare Workers **or run the Python Flask server locally/on any box**.

[![Deploy to Cloudflare Workers](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/nullstacks/cline2api)

Based on [pingmike2/cline2api-workers](https://github.com/pingmike2/cline2api-workers)
(reverse-engineered from [luawei1/cline2api](https://github.com/luawei1/cline2api)).

## Two runtimes, same API

| | Cloudflare Worker | Python (Flask) |
|---|---|---|
| File | `worker.js` | `server.py` |
| Runtime | edge, no server | local machine, VPS, Docker, systemd… |
| Install | `npx wrangler deploy` | `pip install -r requirements.txt` |
| Config | `CLINE_REFRESH_TOKEN` + `API_KEY` secrets | same names as env vars |

Both expose identical endpoints and identical behavior: dynamic model list,
multi-account pool with cooldown rotation, serial request queue, empty-content
retry, forced upstream streaming for the free channels.

## Free models

Verified working (2026-10-18):

| Model | Provider | Status |
|---|---|---|
| `cline-free/nemotron-3.5-super-vl` | NVIDIA (120B) | ✅ verified |
| `cline-free/mimo-v2.6-flash` | Xiaomi (MoE 309B) | ✅ verified |
| `cline-free/muse-spark-1.3-contributor` | Meta (multimodal) | ✅ verified |
| `cline-free/solar-mini4` | 35B MoE | ✅ verified |
| `deepseek/deepseek-v4-flash` | DeepSeek | ✅ verified |
| `z-ai/glm-5.3-flash` | Z.AI | ✅ verified |

Known non-free / dead:

- `cline-free/deepseek-v4.1-flash` (README default of the upstream repo) —
  **retired upstream**, returns 404 `model not found`
- `cline-pass/*` — requires the paid Cline Pass subscription
- `deepseek/deepseek-v4.1-flash` (no `cline-free/` prefix) — paid tier
  (402 without credits)

The model list auto-refreshes from Cline every 10 min (merging the official
`recommended-models` free channel), so `GET /v1/models` is authoritative and
picks up new free models automatically.

## Deploy to Cloudflare Workers

**Option A — button above**, then set the secret below in the dashboard.

**Option B — CLI:**

```bash
git clone https://github.com/nullstacks/cline2api
cd cline2api
npx wrangler login
npx wrangler deploy

# set your account token (see next section) and an API key
npx wrangler secret put CLINE_REFRESH_TOKEN
npx wrangler secret put API_KEY
```

### Environment variables (both runtimes)

| Variable | Type | Required | Purpose |
|---|---|---|---|
| `CLINE_REFRESH_TOKEN` | Secret / env | ✅ | Cline account token(s) — one per line, multi-account pool |
| `API_KEY` | Secret / env | recommended | Client access key (default `cline2api-default-key`; set to empty string to disable auth) |

> After changing secrets, redeploy (or re-run `wrangler deploy`) for them to
> take effect. On the Python side, just restart the process.

## Getting a Cline refreshToken (device auth)

Cline's API requires a Cline account token even for free models. Two ways to
get one:

### Option 1 — Local script (fastest)

```bash
python3 cline_oauth.py
```

1. It prints an authorization URL (`https://authkit.cline.bot/device?user_code=XXXX-XXXX`)
2. Open it in any browser, log in with Google / GitHub / email, approve
3. The script polls automatically and prints the `refreshToken`
4. `npx wrangler secret put CLINE_REFRESH_TOKEN` and paste it — or export it
   for the Python server (next section)

### Option 2 — GitHub Actions (works from your phone)

The repo ships `.github/workflows/get-token.yml`:

1. In **your fork**, add repo secrets `TG_BOT_TOKEN` and `TG_CHAT_ID`
   (the flow pushes the login link and the token to your Telegram — the
   token never appears in Actions logs)
2. Actions → **获取 Cline refreshToken** → Run workflow
3. Open the link from Telegram, approve, receive the token
4. Put it in the Worker secret or Python env as above

### Notes

- The refresh token is long-lived but can expire — if chat calls start
  returning 401/403, re-run `cline_oauth.py` and update the secret/env
- **Multi-account pooling:** put one token per line in `CLINE_REFRESH_TOKEN`;
  when one account's daily free quota runs out (429 `Daily free limit
  reached`), the gateway cools it down (parsing `Try again in Xh Ym`) and
  switches to the next automatically

## Run the Python server

```bash
pip install -r requirements.txt          # flask + httpx
export CLINE_REFRESH_TOKEN='<refreshToken from cline_oauth.py>'
export API_KEY='my-secret-key'           # optional

python3 server.py                        # serves on 0.0.0.0:8080 (PORT/HOST to override)
```

Production options:

```bash
gunicorn -w 1 -b 0.0.0.0:8080 server:app          # keep 1 worker: in-memory account pool
flask --app server run --host 0.0.0.0 --port 8080 # dev server
```

A `Dockerfile` is included: `docker build -t cline2api . && docker run -p 8080:8080 -e CLINE_REFRESH_TOKEN='...' -e API_KEY='...' cline2api`.

## Usage

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer my-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"cline-free/mimo-v2.6-flash","messages":[{"role":"user","content":"hi"}]}'
```

```bash
# Claude Code
export ANTHROPIC_BASE_URL=http://localhost:8080
export ANTHROPIC_API_KEY=my-secret-key
export ANTHROPIC_MODEL=cline-free/nemotron-3.5-super-vl
```

> Browser UA note applies to `workers.dev` deployments only (Cloudflare edge
> error 1010) — the Python server has no such restriction.
>
> Behavior notes (both runtimes): `max_tokens` is stripped (upstream 500s on
> it for free models); free channels are streamed upstream and aggregated for
> non-stream clients; requests are serialized (upstream returns empty on
> concurrency > 1).

## Endpoints

```
GET  /v1/models            model catalog
GET  /v1/health            config diagnostics (account count, auth state)
POST /v1/chat/completions  OpenAI wire (stream + non-stream)
POST /v1/messages          Anthropic wire (auto-converted)
```

## License

MIT — see LICENSE (© luawei1, upstream worker © pingmike2, Python port and
packaging © nullstacks)
