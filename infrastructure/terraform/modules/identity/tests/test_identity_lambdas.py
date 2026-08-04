import importlib.util
import json
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import Mock


class IdentityLambdaTest(unittest.TestCase):
    def setUp(self):
        self.cognito = Mock()
        self.secrets_manager = Mock()
        clients = {
            "cognito-idp": self.cognito,
            "secretsmanager": self.secrets_manager,
        }
        fake_boto3 = types.ModuleType("boto3")
        fake_boto3.client = lambda service: clients[service]
        sys.modules["boto3"] = fake_boto3

        root = Path(__file__).parents[1] / "lambda"
        self.linker = self.load("identity_account_linker", root / "account_linker.py")
        self.configurator = self.load("identity_google_configurator", root / "google_configurator.py")

    def tearDown(self):
        sys.modules.pop("boto3", None)

    def test_native_registration_is_never_auto_confirmed(self):
        event = {"triggerSource": "PreSignUp_SignUp", "response": {}}

        self.assertIs(event, self.linker.handler(event, None))

        self.cognito.assert_not_called()
        self.assertEqual({}, event["response"])

    def test_verified_google_email_links_to_one_verified_native_user(self):
        self.cognito.list_users.return_value = {
            "Users": [
                {
                    "Username": "canonical-subject",
                    "UserStatus": "CONFIRMED",
                    "Attributes": [
                        {"Name": "email", "Value": "learner@example.com"},
                        {"Name": "email_verified", "Value": "true"},
                    ],
                }
            ]
        }
        event = self.google_event()

        result = self.linker.handler(event, None)

        self.cognito.admin_create_user.assert_not_called()
        self.cognito.admin_link_provider_for_user.assert_called_once_with(
            UserPoolId="eu-central-1_pool",
            DestinationUser={
                "ProviderName": "Cognito",
                "ProviderAttributeName": "Cognito_Subject",
                "ProviderAttributeValue": "canonical-subject",
            },
            SourceUser={
                "ProviderName": "Google",
                "ProviderAttributeName": "Cognito_Subject",
                "ProviderAttributeValue": "google-subject",
            },
        )
        self.assertTrue(result["response"]["autoConfirmUser"])
        self.assertTrue(result["response"]["autoVerifyEmail"])

    def test_unverified_existing_native_user_blocks_linking(self):
        self.cognito.list_users.return_value = {
            "Users": [
                {
                    "Username": "unverified",
                    "UserStatus": "UNCONFIRMED",
                    "Attributes": [
                        {"Name": "email", "Value": "learner@example.com"},
                        {"Name": "email_verified", "Value": "false"},
                    ],
                }
            ]
        }

        with self.assertRaisesRegex(ValueError, "Verify the existing email"):
            self.linker.handler(self.google_event(), None)

        self.cognito.admin_link_provider_for_user.assert_not_called()

    def test_google_first_creates_suppressed_canonical_user_then_links(self):
        self.cognito.list_users.return_value = {"Users": []}
        self.cognito.admin_create_user.return_value = {"User": {"Username": "new-canonical"}}

        self.linker.handler(self.google_event(), None)

        create = self.cognito.admin_create_user.call_args.kwargs
        self.assertEqual("SUPPRESS", create["MessageAction"])
        self.assertNotIn("learner@example.com", create["TemporaryPassword"])
        self.cognito.admin_set_user_password.assert_called_once()
        self.assertTrue(self.cognito.admin_set_user_password.call_args.kwargs["Permanent"])
        destination = self.cognito.admin_link_provider_for_user.call_args.kwargs["DestinationUser"]
        self.assertEqual("new-canonical", destination["ProviderAttributeValue"])

    def test_concurrent_google_first_reuses_the_single_verified_winner(self):
        raced = RuntimeError("already created")
        raced.response = {"Error": {"Code": "UsernameExistsException"}}
        self.cognito.admin_create_user.side_effect = raced
        self.cognito.list_users.side_effect = [
            {"Users": []},
            {
                "Users": [
                    {
                        "Username": "race-winner",
                        "UserStatus": "CONFIRMED",
                        "Attributes": [
                            {"Name": "email", "Value": "learner@example.com"},
                            {"Name": "email_verified", "Value": "true"},
                        ],
                    }
                ]
            },
        ]

        self.linker.handler(self.google_event(), None)

        destination = self.cognito.admin_link_provider_for_user.call_args.kwargs["DestinationUser"]
        self.assertEqual("race-winner", destination["ProviderAttributeValue"])

    def test_configurator_reads_secret_without_returning_it(self):
        self.secrets_manager.get_secret_value.return_value = {
            "SecretString": json.dumps({"clientId": "client-id", "clientSecret": "very-secret"})
        }
        missing = RuntimeError("missing")
        missing.response = {"Error": {"Code": "ResourceNotFoundException"}}
        self.cognito.describe_identity_provider.side_effect = missing

        result = self.configurator.handler(
            {"userPoolId": "pool", "secretArn": "secret-arn", "tf": {"action": "create"}},
            None,
        )

        self.assertEqual({"status": "created"}, result)
        details = self.cognito.create_identity_provider.call_args.kwargs["ProviderDetails"]
        self.assertEqual("very-secret", details["client_secret"])
        self.assertNotIn("very-secret", json.dumps(result))

    def test_configurator_delete_does_not_read_secret(self):
        result = self.configurator.handler(
            {"userPoolId": "pool", "secretArn": "secret-arn", "tf": {"action": "delete"}},
            None,
        )

        self.assertEqual({"status": "deleted"}, result)
        self.secrets_manager.get_secret_value.assert_not_called()

    @staticmethod
    def load(name, path):
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    @staticmethod
    def google_event():
        return {
            "triggerSource": "PreSignUp_ExternalProvider",
            "userPoolId": "eu-central-1_pool",
            "userName": "Google_google-subject",
            "request": {
                "userAttributes": {
                    "email": "Learner@Example.com",
                    "email_verified": "true",
                    "name": "Learner",
                }
            },
            "response": {},
        }


if __name__ == "__main__":
    unittest.main()
