#!/usr/bin/env python3
"""Export actual account service costs; never mislabel shared-account totals as project costs."""
import argparse
from datetime import date
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--start", required=True)
parser.add_argument("--end", required=True, help="Exclusive end date")
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
if date.fromisoformat(args.start) >= date.fromisoformat(args.end):
    parser.error("end must be after start")
command = ["aws", "ce", "get-cost-and-usage", "--region", "us-east-1", "--time-period",
           f"Start={args.start},End={args.end}", "--granularity", "DAILY", "--metrics",
           "UnblendedCost", "--group-by", "Type=DIMENSION,Key=SERVICE", "--output", "json"]
data = json.loads(subprocess.check_output(command, text=True))
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({"scope": "whole-account (includes unrelated labs)",
                                   "billing_data": data}, indent=2) + "\n")
print("Saved account-level costs. Attribute project usage separately using activated allocation tags and resource inventory.")
