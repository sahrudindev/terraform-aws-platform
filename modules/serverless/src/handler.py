"""Demo endpoint for the API Gateway in front of this function.

Returns something a reader can verify against the repository: which commit is
deployed, which environment answered, and where the request landed. Reads no
data and holds no state, which is why the route has no authorizer - see the
checkov skip on aws_apigatewayv2_route in main.tf.
"""

import json
import os
from datetime import datetime, timezone


def handler(event, context):
    body = {
        "message": "Provisioned by Terraform, deployed by GitHub Actions over OIDC.",
        "repository": "https://github.com/sahrudindev/terraform-aws-platform",
        "environment": os.environ.get("ENVIRONMENT", "unknown"),
        "region": os.environ.get("AWS_REGION", "unknown"),
        "commit": os.environ.get("GIT_COMMIT", "unknown"),
        "path": event.get("rawPath", "/"),
        "served_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "request_id": getattr(context, "aws_request_id", None),
        "how_this_got_here": [
            "pull request opened",
            "fmt, validate, tflint, terraform test, checkov, trivy, gitleaks",
            "terraform plan posted as a pull request comment",
            "merged to main",
            "apply paused for a human approval",
            "role assumed via OIDC, credentials valid one hour",
            "you are reading the result",
        ],
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(body, indent=2),
    }
