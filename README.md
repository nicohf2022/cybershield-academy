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