#!/bin/bash
set -euxo pipefail

dnf install -y python3 >/dev/null 2>&1 || true

cat >/opt/ssrf-lab.py <<'PY'
from datetime import datetime, timezone
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import time
from urllib.parse import urlparse, parse_qs
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

PORT = ${app_port}
MAX_PREVIEW = 8 * 1024

CATALOG = [
    {
        "name": "Payments API",
        "environment": "PROD",
        "description": "Public health endpoint used by the payments platform.",
        "url": "https://httpbin.org/status/200",
    },
    {
        "name": "Customer Portal",
        "environment": "PROD",
        "description": "Customer-facing portal reachability check.",
        "url": "https://example.com/",
    },
    {
        "name": "Inventory API",
        "environment": "SHARED",
        "description": "Inventory service response validation.",
        "url": "https://httpbin.org/json",
    },
    {
        "name": "Release Artifact Mirror",
        "environment": "DEV",
        "description": "Connectivity check for release artifact endpoints.",
        "url": "https://httpbin.org/anything/releases/latest",
    },
]

CSS = """
:root {
  color-scheme: dark;
  --bg: #0b1220;
  --panel: #111b2e;
  --panel-2: #162238;
  --border: #263650;
  --text: #e8edf5;
  --muted: #9badc5;
  --accent: #66a3ff;
  --success: #54d38a;
  --warning: #f6c453;
  --danger: #ff7272;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: radial-gradient(circle at top left, #14233d 0, var(--bg) 38%);
  color: var(--text);
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
.shell { max-width: 1120px; margin: 0 auto; padding: 38px 28px 56px; }
.topbar { display:flex; justify-content:space-between; align-items:center; gap:24px; margin-bottom:28px; }
.brand { display:flex; align-items:center; gap:14px; }
.logo {
  width:46px; height:46px; border-radius:12px; display:grid; place-items:center;
  background:linear-gradient(145deg,#1d73e8,#69a7ff); font-weight:800; box-shadow:0 12px 30px #0006;
}
h1 { font-size:24px; margin:0 0 4px; letter-spacing:-.02em; }
.subtitle { margin:0; color:var(--muted); font-size:14px; }
.status-pill { border:1px solid #31563f; background:#14291d; color:#8ee8ac; padding:8px 12px; border-radius:999px; font-size:13px; }
.hero {
  background:linear-gradient(140deg,#14223a,#0f192a); border:1px solid var(--border); border-radius:18px;
  padding:24px; box-shadow:0 20px 55px #0005; margin-bottom:26px;
}
.hero h2 { margin:0 0 8px; font-size:20px; }
.hero p { margin:0 0 18px; color:var(--muted); line-height:1.5; }
.url-form { display:grid; grid-template-columns:1fr auto; gap:10px; }
.url-form input {
  width:100%; border:1px solid #334662; background:#0a1322; color:var(--text); border-radius:10px;
  padding:13px 14px; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; outline:none;
}
.url-form input:focus { border-color:var(--accent); box-shadow:0 0 0 3px #4b91ff22; }
button {
  border:0; border-radius:10px; padding:12px 17px; background:var(--accent); color:#07101f; font-weight:750;
  cursor:pointer; transition:.15s transform,.15s filter;
}
button:hover { filter:brightness(1.08); transform:translateY(-1px); }
.section-title { display:flex; align-items:end; justify-content:space-between; margin:28px 0 13px; }
.section-title h3 { margin:0; font-size:16px; }
.section-title span { color:var(--muted); font-size:12px; }
.overview { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:14px; }
.overview-card { background:var(--panel); border:1px solid var(--border); border-radius:14px; padding:17px; display:flex; flex-direction:column; gap:5px; }
.overview-label { color:var(--muted); font-size:11px; text-transform:uppercase; letter-spacing:.08em; }
.overview-card strong { font-size:16px; }
.overview-card small { color:#7186a3; font-size:11px; line-height:1.4; }
.catalog { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; }
.card { background:var(--panel); border:1px solid var(--border); border-radius:14px; padding:17px; }
.card-head { display:flex; align-items:flex-start; justify-content:space-between; gap:12px; }
.card h4 { margin:0 0 5px; font-size:15px; }
.card p { margin:0 0 16px; color:var(--muted); font-size:13px; line-height:1.45; }
.badge { border:1px solid #385173; color:#a8c8f5; background:#13233a; border-radius:999px; padding:4px 8px; font-size:11px; }
.target { color:#7186a3; font-size:11px; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; margin-bottom:14px; }
.card button { background:#1c2d47; border:1px solid #345174; color:#d6e7ff; padding:9px 12px; font-weight:650; }
.result { margin-top:26px; background:var(--panel); border:1px solid var(--border); border-radius:16px; overflow:hidden; }
.result-head { display:flex; justify-content:space-between; gap:18px; padding:18px 20px; border-bottom:1px solid var(--border); background:#132039; }
.result-head h3 { margin:0 0 4px; font-size:16px; }
.result-head p { margin:0; color:var(--muted); font-size:12px; word-break:break-all; }
.result-state { color:var(--success); font-weight:750; white-space:nowrap; }
.metrics { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); border-bottom:1px solid var(--border); }
.metric { padding:16px 18px; border-right:1px solid var(--border); }
.metric:last-child { border-right:0; }
.metric-label { color:var(--muted); font-size:11px; text-transform:uppercase; letter-spacing:.08em; }
.metric-value { margin-top:6px; font-size:14px; font-weight:650; overflow-wrap:anywhere; }
.preview-wrap { padding:18px 20px 22px; }
.preview-title { margin:0 0 10px; color:var(--muted); font-size:12px; text-transform:uppercase; letter-spacing:.08em; }
pre {
  margin:0; padding:16px; max-height:380px; overflow:auto; border-radius:10px; border:1px solid #283b58;
  background:#080f1b; color:#dce8f8; font:12.5px/1.55 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; white-space:pre-wrap; word-break:break-word;
}
.error { border-color:#633b43; }
.error .result-head { background:#321b22; }
.error .result-state { color:var(--danger); }
.footer { margin-top:28px; text-align:center; color:#5f7391; font-size:11px; }
@media (max-width:760px) {
  .catalog { grid-template-columns:1fr; }
  .overview { grid-template-columns:1fr; }
  .metrics { grid-template-columns:repeat(2,1fr); }
  .metric { border-bottom:1px solid var(--border); }
  .url-form { grid-template-columns:1fr; }
  .topbar { align-items:flex-start; flex-direction:column; }
}
"""


def catalog_html():
    cards = []
    for item in CATALOG:
        cards.append(f"""
        <article class="card">
          <div class="card-head">
            <div>
              <h4>{escape(item['name'])}</h4>
              <p>{escape(item['description'])}</p>
            </div>
            <span class="badge">{escape(item['environment'])}</span>
          </div>
          <div class="target">{escape(item['url'])}</div>
          <form action="/fetch" method="get">
            <input type="hidden" name="url" value="{escape(item['url'], quote=True)}">
            <button type="submit">Check endpoint</button>
          </form>
        </article>
        """)
    return "".join(cards)


def page(result=""):
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>CloudOps Fleet Health</title>
  <style>{CSS}</style>
</head>
<body>
  <main class="shell">
    <header class="topbar">
      <div class="brand">
        <div class="logo">CO</div>
        <div>
          <h1>CloudOps Fleet Health</h1>
          <p class="subtitle">Endpoint monitoring and infrastructure inventory for shared workloads</p>
        </div>
      </div>
      <div class="status-pill">● Platform online</div>
    </header>

    <section class="hero">
      <h2>Check an endpoint</h2>
      <p>Validate reachability and inspect the HTTP response from the shared CloudOps network.</p>
      <form class="url-form" action="/fetch" method="get">
        <input name="url" type="url" required placeholder="https://service.example.com/health" autocomplete="off">
        <button type="submit">Run health check</button>
      </form>
    </section>

    <div class="section-title">
      <h3>Fleet overview</h3>
      <span>scheduled inventory</span>
    </div>
    <section class="overview">
      <div class="overview-card"><span class="overview-label">Inventory scope</span><strong>SHARED workloads</strong><small>CloudOps inventory boundary</small></div>
      <div class="overview-card"><span class="overview-label">Inventory profile</span><strong>Host + runtime</strong><small>Standard fleet metadata profile</small></div>
      <div class="overview-card"><span class="overview-label">Endpoint catalog</span><strong>4 targets</strong><small>On-demand health validation</small></div>
    </section>

    <div class="section-title">
      <h3>Service catalog</h3>
      <span>4 registered endpoints</span>
    </div>
    <section class="catalog">{catalog_html()}</section>

    {result}

    <footer class="footer">CloudOps Fleet Health · Platform Services · Internal utility</footer>
  </main>
</body>
</html>"""


def readable_body(raw, content_type):
    text = raw.decode("utf-8", errors="replace")
    if "json" in content_type.lower():
        try:
            return json.dumps(json.loads(text), indent=2)
        except json.JSONDecodeError:
            pass
    return text


def result_html(target, status, content_type, body, elapsed_ms, total_bytes):
    parsed = urlparse(target)
    preview = readable_body(body, content_type)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    return f"""
    <section class="result">
      <div class="result-head">
        <div>
          <h3>Health check result</h3>
          <p>{escape(target)}</p>
        </div>
        <div class="result-state">● REACHABLE</div>
      </div>
      <div class="metrics">
        <div class="metric"><div class="metric-label">HTTP</div><div class="metric-value">{status}</div></div>
        <div class="metric"><div class="metric-label">Latency</div><div class="metric-value">{elapsed_ms} ms</div></div>
        <div class="metric"><div class="metric-label">Content type</div><div class="metric-value">{escape(content_type.split(';')[0])}</div></div>
        <div class="metric"><div class="metric-label">Response size</div><div class="metric-value">{total_bytes} B</div></div>
        <div class="metric"><div class="metric-label">Target host</div><div class="metric-value">{escape(parsed.hostname or '-')}</div></div>
      </div>
      <div class="preview-wrap">
        <div class="preview-title">Response preview · {timestamp}</div>
        <pre>{escape(preview)}</pre>
      </div>
    </section>
    """


def error_html(target, message, elapsed_ms):
    parsed = urlparse(target)
    return f"""
    <section class="result error">
      <div class="result-head">
        <div>
          <h3>Health check result</h3>
          <p>{escape(target)}</p>
        </div>
        <div class="result-state">● FAILED</div>
      </div>
      <div class="metrics">
        <div class="metric"><div class="metric-label">Latency</div><div class="metric-value">{elapsed_ms} ms</div></div>
        <div class="metric"><div class="metric-label">Target host</div><div class="metric-value">{escape(parsed.hostname or '-')}</div></div>
      </div>
      <div class="preview-wrap">
        <div class="preview-title">Error details</div>
        <pre>{escape(message)}</pre>
      </div>
    </section>
    """


class Handler(BaseHTTPRequestHandler):
    def html(self, body, status=200):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self.html(page())
            return

        if parsed.path != "/fetch":
            self.send_error(404)
            return

        target = parse_qs(parsed.query).get("url", [""])[0].strip()
        if not target:
            self.html(page(error_html("", "Missing URL.", 0)), 400)
            return

        start = time.perf_counter()
        try:
            # Intentionally vulnerable for the lab: the backend performs a GET to any user-supplied URL.
            # There is no allowlist and no filtering of localhost, private, or link-local destinations.
            req = Request(target, headers={"User-Agent": "cloudops-endpoint-health/1.0"}, method="GET")
            with urlopen(req, timeout=4) as response:
                raw = response.read(MAX_PREVIEW + 1)
                truncated = len(raw) > MAX_PREVIEW
                body = raw[:MAX_PREVIEW]
                status = response.status
                content_type = response.headers.get("Content-Type", "text/plain")
                content_length = response.headers.get("Content-Length")

            elapsed_ms = int((time.perf_counter() - start) * 1000)
            total_bytes = content_length if content_length and content_length.isdigit() else len(raw)
            if truncated:
                body += b"\n\n[preview truncated]"
            self.html(page(result_html(target, status, content_type, body, elapsed_ms, total_bytes)))
        except HTTPError as exc:
            elapsed_ms = int((time.perf_counter() - start) * 1000)
            self.html(page(error_html(target, f"HTTP {exc.code}: {exc.reason}", elapsed_ms)), 502)
        except (URLError, TimeoutError, ValueError) as exc:
            elapsed_ms = int((time.perf_counter() - start) * 1000)
            self.html(page(error_html(target, str(exc), elapsed_ms)), 502)

    def log_message(self, fmt, *args):
        print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), fmt % args), flush=True)


ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
PY

cat >/etc/systemd/system/ssrf-lab.service <<'UNIT'
[Unit]
Description=Intentionally vulnerable CloudOps Fleet Health lab
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/ssrf-lab.py
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now ssrf-lab
