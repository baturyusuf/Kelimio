import json

import boto3


cognito = boto3.client("cognito-idp")
secrets_manager = boto3.client("secretsmanager")


def _error_code(error):
    return getattr(error, "response", {}).get("Error", {}).get("Code")


def _provider_configuration(secret_arn):
    response = secrets_manager.get_secret_value(SecretId=secret_arn)
    value = json.loads(response["SecretString"])
    client_id = value.get("clientId", "").strip()
    client_secret = value.get("clientSecret", "").strip()
    if not client_id or not client_secret:
        raise ValueError("Google OIDC secret must contain nonblank clientId and clientSecret")
    return {
        "client_id": client_id,
        "client_secret": client_secret,
        "authorize_scopes": "openid email profile",
    }


def handler(event, _context):
    user_pool_id = event["userPoolId"]
    action = event.get("tf", {}).get("action", "create")
    if action == "delete":
        try:
            cognito.delete_identity_provider(UserPoolId=user_pool_id, ProviderName="Google")
        except Exception as error:
            if _error_code(error) != "ResourceNotFoundException":
                raise
        return {"status": "deleted"}

    details = _provider_configuration(event["secretArn"])
    attributes = {
        "email": "email",
        "email_verified": "email_verified",
        "family_name": "family_name",
        "given_name": "given_name",
        "name": "name",
    }
    try:
        cognito.describe_identity_provider(UserPoolId=user_pool_id, ProviderName="Google")
        cognito.update_identity_provider(
            UserPoolId=user_pool_id,
            ProviderName="Google",
            ProviderDetails=details,
            AttributeMapping=attributes,
        )
        status = "updated"
    except Exception as error:
        if _error_code(error) != "ResourceNotFoundException":
            raise
        cognito.create_identity_provider(
            UserPoolId=user_pool_id,
            ProviderName="Google",
            ProviderType="Google",
            ProviderDetails=details,
            AttributeMapping=attributes,
        )
        status = "created"
    return {"status": status}
