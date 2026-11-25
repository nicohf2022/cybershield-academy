# Shared responsibility model

| Layer | AWS responsibility | Team responsibility |
|---|---|---|
| Physical infrastructure | Datacenters, hardware, hypervisor and managed-service infrastructure | Select regions and design for outage; AWS does not automatically fail over this app |
| EC2/OS | VM service and underlying isolation | AMI selection, package updates, Docker, Buildx, host permissions, database process and patching |
| Network | VPC/network service operation | CIDRs, routes, security groups, public exposure and TLS decisions |
| PostgreSQL | Underlying EC2/EBS services | Database users, password handling, consistency, dumps, restore tests and data integrity |
| S3 | Object storage/replication service | Private policies, versioning, encryption choice, replication IAM, retention and testing |
| Identity | IAM/STS/OIDC service operation | Trust subjects, role policies, permission boundaries, reviews and temporary local sessions |
| Terraform/GitHub | Provider/GitHub service availability under their terms | State protection, independent recovery state, safe plans, approvals, locking and secrets |
| Monitoring/cost | CloudWatch/Budgets mechanisms | Logs, useful alarms and actual triggering, recipients, budgets, cost review and teardown |

Replication is not protection against every logical corruption: a bad new backup
can also replicate. Retained versions, trusted manifests, marker verification and
restore exercises are team controls. A budget is an alert, not a hard spending
cap. This demo has no regulated/student production data and offers no production
availability SLA. Independent recovery is not proven until the state migration
and recorded regional-failure exercise succeed.
