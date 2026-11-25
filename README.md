# CyberShield Academy

Simulacro de recuperación ante desastres implementado en AWS mediante Terraform.

## Integrantes

- Nicolas Hernandez
- Bruno Cánepa

## Objetivo

Demostrar la recuperación de una aplicación y una base de datos PostgreSQL ante la caída completa de una región de AWS.

## Arquitectura

La solución utiliza una estrategia pilot light:

- La región A funciona como región principal.
- La región B conserva los respaldos replicados.
- PostgreSQL genera un backup cada hora.
- Los backups se almacenan en Amazon S3.
- S3 replica los archivos hacia la región B.
- Terraform crea la infraestructura de recuperación durante el failover.
- GitHub Actions ejecuta los procesos de despliegue, failover y destrucción.

## Tecnologías

- AWS
- Terraform
- GitHub Actions
- Docker
- PostgreSQL
- Amazon EC2
- Amazon EBS
- Amazon S3
- Amazon CloudWatch
- Amazon SNS

## Estructura del repositorio

- `docs`: arquitectura, IAM, FinOps y procedimientos.
- `app`: aplicación y base de datos en contenedores.
- `infra/bootstrap`: creación inicial del state remoto.
- `infra/modules`: módulos reutilizables de Terraform.
- `infra/envs`: configuración de las regiones A y B.
- `.github/workflows`: pipelines de integración, despliegue y recuperación.

## Estado del proyecto

En desarrollo.

## Current implementation and commands

The application now uses **one parameterized root** at `infra/envs/dr`.
`region-a` and `region-b` contain inputs/backend settings only. Do not run Terraform
from those old root directories. Existing resource addresses are preserved with
reviewable moved blocks; no state migration is automatic.

```bash
export AWS_PROFILE=cybershield
# Supply your actual public IP privately; the code defaults to loopback ingress.
export TF_VAR_allowed_http_cidrs='["YOUR-PUBLIC-IP/32"]'
bash scripts/tf.sh region-b init
bash scripts/tf.sh region-b plan -out=/tmp/region-b.tfplan
bash scripts/tf.sh region-a init
bash scripts/tf.sh region-a plan -out=/tmp/region-a.tfplan
```

Obtain explicit approval before applying a saved plan. The existing primary
instance still has pending startup replacement: pin a verified backup and review
the plan before any replacement. Region B compute defaults off; recovery needs
an independently accessible backend and a pinned restore manifest.

At session end, take a final verified backup and plan `enable_compute=false` for
each active region. The approved manual teardown workflow removes hourly demo
resources while preserving backup buckets, replication and Terraform state.
Complete data deletion is a separate reviewed operation.

- [Safe adoption and state independence](docs/runbooks/shared-root.md)
- [GitHub Actions roles, variables and required approvals](docs/runbooks/github-actions.md)
- [DR exercise, failback and RTO/RPO measurement](docs/runbooks/disaster-recovery.md)
- [Architecture and provider choice](docs/architecture/architecture.md)
- [IAM matrix](docs/iam/matrix.md) and [security decisions](docs/security.md)
- [FinOps](docs/finops/report.md), [responsibility model](docs/shared-responsibility.md)
- [Business summary](docs/executive-summary.md), [presentation](docs/presentation.md)
- [Implemented versus verified coverage](docs/status.md)

The new shared-root/workflow code is not evidence of a deployed or recorded DR
exercise. See the status table before claiming completion.
