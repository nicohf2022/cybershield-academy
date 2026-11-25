aws_region         = "us-east-1"
recovery_region    = "us-east-2"
environment        = "primary"
name_prefix        = "cybershield-primary"
enable_compute     = true
enable_replication = true
# Supply allowed_http_cidrs privately or TF_VAR_allowed_http_cidrs (JSON list).
