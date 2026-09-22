# nginx upload limits (EC2)

Why this exists: nginx's default `client_max_body_size` is 1 MB, and the
production server still uses it. Any request over 1 MB — for example a 7 MB PDF
sent to `POST /api/ai/smart-case/optimize` — is refused by nginx with an HTML
`413 Request Entity Too Large` before Node.js sees it. That page carries no CORS
headers, so the browser reports it as a CORS error.

`lawyer-api-uploads.conf` raises the limit **only** on the upload endpoints:

| Location | Limit | Why |
| --- | --- | --- |
| `/api/ai/smart-case/optimize` | 21m | One original up to 20 MB (`AI_OPTIMIZE_MAX_MB`) + multipart overhead |
| `/api/ai/smart-case/analyze` | 41m | 10 × 3 MB documents (`AI_UPLOAD_MAX_MB`) + 10 MB voice note |
| `/api/ai/transcribe` | 11m | One voice note up to 10 MB |
| `/api/documents/upload`, `/api/documents/:id/replace` | 4m | One 3 MB acknowledgement |
| everything else | unchanged | |

Node still enforces the real limits: documents over 3 MB are refused with 413,
and the optimize endpoint refuses originals over 20 MB.

## Apply (on the EC2 host)

```bash
# 1. See the existing site config: the server block and the /api proxy target.
sudo nginx -T 2>/dev/null | grep -nE "server_name|listen|location|proxy_pass|client_max_body_size"
```

```bash
# 2. Install the snippet. Edit proxy_pass in it first if step 1 shows a target
#    other than http://127.0.0.1:5000.
sudo cp ~/Lawyer-App/deploy/nginx/lawyer-api-uploads.conf /etc/nginx/snippets/
```

3. In the site file from step 1 (usually `/etc/nginx/sites-available/default`),
   add this line inside the `server { ... }` block for
   `lawyerappvizag.duckdns.org` on port 443, next to `location /api/`:

   ```nginx
   include /etc/nginx/snippets/lawyer-api-uploads.conf;
   ```

```bash
# 4. Validate, then reload (no restart, no dropped connections).
sudo nginx -t && sudo systemctl reload nginx
```

## Backend prerequisites

```bash
# Ghostscript does the PDF optimization. Without it the endpoint returns 503.
sudo apt-get install -y ghostscript && gs --version
```

In `~/Lawyer-App/backend/.env` (never commit it):

```
AI_UPLOAD_MAX_MB=3
AI_OPTIMIZE_MAX_MB=20
ALLOWED_ORIGINS=http://127.0.0.1:5174,http://localhost:5174
```

`ALLOWED_ORIGINS` must list every browser origin exactly. `*` is ignored.
Then apply the new environment:

```bash
pm2 restart lawyer-backend --update-env
```

## Verify

```bash
# A 7 MB unauthenticated POST must now reach Node: expect 401 JSON, not 413 HTML.
head -c 7000000 /dev/zero > /tmp/probe.bin && curl -s -o /dev/null -w "%{http_code}\n" -F "document=@/tmp/probe.bin;type=application/pdf" https://lawyerappvizag.duckdns.org/api/ai/smart-case/optimize; rm /tmp/probe.bin
```

```bash
# A 22 MB POST must get the API's JSON 413 with CORS headers.
head -c 22000000 /dev/zero > /tmp/probe.bin && curl -s -D - -o /dev/null -H "Origin: http://127.0.0.1:5174" -F "document=@/tmp/probe.bin;type=application/pdf" https://lawyerappvizag.duckdns.org/api/ai/smart-case/optimize | grep -iE "^HTTP|access-control-allow-origin"; rm /tmp/probe.bin
```
