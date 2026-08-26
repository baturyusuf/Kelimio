import re
import unittest
from pathlib import Path


class BootstrapTerraformTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.main = (Path(__file__).parents[1] / "main.tf").read_text(encoding="utf-8")

    def test_production_deploy_can_manage_declared_cognito_branding(self):
        match = re.search(
            r'data\s+"aws_iam_policy_document"\s+"github_production_deploy"\s*\{'
            r'(?P<body>.*?)\n\}',
            self.main,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "production deploy policy must remain declared")
        policy = match.group("body")

        for action in (
            "cognito-idp:CreateManagedLoginBranding",
            "cognito-idp:DeleteManagedLoginBranding",
            "cognito-idp:UpdateManagedLoginBranding",
        ):
            with self.subTest(action=action):
                self.assertIn(f'"{action}"', policy)

    def test_production_deploy_can_manage_import_worker_autoscaling(self):
        for action in (
            "application-autoscaling:RegisterScalableTarget",
            "application-autoscaling:PutScalingPolicy",
            "application-autoscaling:DeregisterScalableTarget",
            "application-autoscaling:DeleteScalingPolicy",
        ):
            with self.subTest(action=action):
                self.assertIn(f'"{action}"', self.main)

        self.assertIn('"ecs.application-autoscaling.amazonaws.com"', self.main)


if __name__ == "__main__":
    unittest.main()
