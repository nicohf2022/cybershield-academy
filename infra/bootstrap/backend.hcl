# Bootstrap state destination; migrate existing local state with init -migrate-state.
bucket       = "cybershield-tfstate-079754672968"
key          = "bootstrap/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
