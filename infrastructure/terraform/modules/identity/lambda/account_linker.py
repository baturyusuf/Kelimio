import secrets
import string

import boto3


cognito = boto3.client("cognito-idp")
_ORIGIN_ATTRIBUTE = "custom:canonical_origin"
_ORIGIN_VALUE = "google_linker_v1"


def _error_code(error):
    return getattr(error, "response", {}).get("Error", {}).get("Code")


def _attribute_map(user):
    return {item["Name"]: item["Value"] for item in user.get("Attributes", [])}


def _verified(value):
    return value is True or str(value).lower() == "true"


def _email_filter(value):
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'email = "{escaped}"'


def _strong_password():
    alphabet = string.ascii_letters + string.digits + "!#$%&*+-=?^_~"
    chars = ["A", "a", "1", "!"] + [secrets.choice(alphabet) for _ in range(60)]
    secrets.SystemRandom().shuffle(chars)
    return "".join(chars)


def _native_users(user_pool_id, email):
    response = cognito.list_users(
        UserPoolId=user_pool_id,
        Filter=_email_filter(email),
        Limit=10,
    )
    return [user for user in response.get("Users", []) if user.get("UserStatus") != "EXTERNAL_PROVIDER"]


def _create_canonical_user(user_pool_id, email, attributes):
    password = _strong_password()
    user_attributes = [
        {"Name": "email", "Value": email},
        {"Name": "email_verified", "Value": "true"},
        {"Name": _ORIGIN_ATTRIBUTE, "Value": _ORIGIN_VALUE},
    ]
    for name in ("name", "given_name", "family_name"):
        value = attributes.get(name)
        if value:
            user_attributes.append({"Name": name, "Value": value})
    response = cognito.admin_create_user(
        UserPoolId=user_pool_id,
        Username=email,
        UserAttributes=user_attributes,
        TemporaryPassword=password,
        MessageAction="SUPPRESS",
    )
    username = response["User"]["Username"]
    cognito.admin_set_user_password(
        UserPoolId=user_pool_id,
        Username=username,
        Password=password,
        Permanent=True,
    )
    return username


def handler(event, _context):
    if event.get("triggerSource") != "PreSignUp_ExternalProvider":
        return event

    provider_username = event.get("userName", "")
    provider, separator, provider_subject = provider_username.partition("_")
    if provider != "Google" or not separator or not provider_subject:
        raise ValueError("Only the approved Google identity provider can use this linking flow")

    attributes = event.get("request", {}).get("userAttributes", {})
    email = attributes.get("email", "").strip().lower()
    if not email or not _verified(attributes.get("email_verified")):
        raise ValueError("Google must provide a verified email before account linking")

    user_pool_id = event["userPoolId"]
    candidates = _native_users(user_pool_id, email)
    verified_candidates = [
        user for user in candidates if _verified(_attribute_map(user).get("email_verified"))
    ]
    if any(not _verified(_attribute_map(user).get("email_verified")) for user in candidates):
        raise ValueError("Verify the existing email account before signing in with Google")
    if len(verified_candidates) > 1:
        raise ValueError("Account linking is ambiguous and requires support review")

    if verified_candidates:
        destination = verified_candidates[0]
        destination_username = destination["Username"]
        destination_attributes = _attribute_map(destination)
        if (
            destination.get("UserStatus") == "FORCE_CHANGE_PASSWORD"
            and destination_attributes.get(_ORIGIN_ATTRIBUTE) == _ORIGIN_VALUE
        ):
            cognito.admin_set_user_password(
                UserPoolId=user_pool_id,
                Username=destination_username,
                Password=_strong_password(),
                Permanent=True,
            )
    else:
        try:
            destination_username = _create_canonical_user(user_pool_id, email, attributes)
        except Exception as error:
            if _error_code(error) not in {"AliasExistsException", "UsernameExistsException"}:
                raise
            raced_candidates = [
                user
                for user in _native_users(user_pool_id, email)
                if _verified(_attribute_map(user).get("email_verified"))
            ]
            if len(raced_candidates) != 1:
                raise ValueError("Concurrent account linking requires support review") from error
            destination_username = raced_candidates[0]["Username"]

    cognito.admin_link_provider_for_user(
        UserPoolId=user_pool_id,
        DestinationUser={
            "ProviderName": "Cognito",
            "ProviderAttributeName": "Cognito_Subject",
            "ProviderAttributeValue": destination_username,
        },
        SourceUser={
            "ProviderName": "Google",
            "ProviderAttributeName": "Cognito_Subject",
            "ProviderAttributeValue": provider_subject,
        },
    )
    event.setdefault("response", {})["autoConfirmUser"] = True
    event["response"]["autoVerifyEmail"] = True
    return event
