import json


def handler(event, context):
    """Contoh fungsi Lambda yang dikelola Terraform."""
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Hello dari Lambda yang dikelola Terraform!",
                "path": event.get("rawPath", "/"),
            }
        ),
    }
