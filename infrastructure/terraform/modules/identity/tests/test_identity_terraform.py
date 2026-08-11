import re
import unittest
from pathlib import Path


class IdentityTerraformTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.main = (Path(__file__).parents[1] / "main.tf").read_text(encoding="utf-8")

    def test_managed_login_v2_assigns_branding_to_android_client(self):
        self.assertRegex(
            self.main,
            r'resource\s+"aws_cognito_user_pool_domain"\s+"this"\s*\{[^}]*'
            r'managed_login_version\s*=\s*2[^}]*\}',
        )

        match = re.search(
            r'resource\s+"aws_cognito_managed_login_branding"\s+"android"\s*\{'
            r'(?P<body>[^}]*)\}',
            self.main,
        )
        self.assertIsNotNone(match, "Managed Login v2 requires an app-client branding style")
        body = match.group("body")
        self.assertRegex(body, r'user_pool_id\s*=\s*aws_cognito_user_pool\.this\.id')
        self.assertRegex(body, r'client_id\s*=\s*aws_cognito_user_pool_client\.android\.id')
        self.assertRegex(body, r'use_cognito_provided_values\s*=\s*true')
        self.assertRegex(
            body,
            r'depends_on\s*=\s*\[aws_cognito_user_pool_domain\.this\]',
        )


if __name__ == "__main__":
    unittest.main()
