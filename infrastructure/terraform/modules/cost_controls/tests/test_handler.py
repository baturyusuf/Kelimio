import importlib.util
import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import Mock


class CostGovernorTest(unittest.TestCase):
    def setUp(self):
        self.ssm = Mock()
        self.ec2 = Mock()
        self.rds = Mock()
        clients = {"ssm": self.ssm, "ec2": self.ec2, "rds": self.rds}
        fake_boto3 = types.ModuleType("boto3")
        fake_boto3.client = lambda service: clients[service]
        sys.modules["boto3"] = fake_boto3

        path = Path(__file__).parents[1] / "lambda" / "handler.py"
        spec = importlib.util.spec_from_file_location("cost_governor_handler", path)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

        os.environ["CONTROL_TOPIC_MODES"] = (
            '{"arn:conserve":"CONSERVE","arn:read-only":"READ_ONLY",'
            '"arn:suspend":"SUSPENDED"}'
        )
        os.environ["OPERATING_MODE_PARAMETER"] = "/kelimio/production/operating-mode"
        os.environ["EC2_INSTANCE_IDS"] = "[]"
        os.environ["RDS_INSTANCE_IDENTIFIERS"] = "[]"

    def tearDown(self):
        sys.modules.pop("boto3", None)

    def test_moves_to_stricter_mode(self):
        self.ssm.get_parameter.return_value = {"Parameter": {"Value": "NORMAL"}}

        result = self.module.handler(self.event("arn:read-only"), None)

        self.ssm.put_parameter.assert_called_once_with(
            Name="/kelimio/production/operating-mode",
            Value="READ_ONLY",
            Type="String",
            Overwrite=True,
        )
        self.assertEqual("READ_ONLY", result["mode"])
        self.assertTrue(result["changed"])

    def test_delayed_lower_threshold_cannot_relax_suspended_mode(self):
        self.ssm.get_parameter.return_value = {"Parameter": {"Value": "SUSPENDED"}}

        result = self.module.handler(self.event("arn:conserve"), None)

        self.ssm.put_parameter.assert_not_called()
        self.assertEqual("SUSPENDED", result["mode"])
        self.assertFalse(result["changed"])

    def test_unknown_topic_fails_closed_without_writing(self):
        with self.assertRaisesRegex(ValueError, "unrecognized topic"):
            self.module.handler(self.event("arn:unknown"), None)

        self.ssm.get_parameter.assert_not_called()
        self.ssm.put_parameter.assert_not_called()

    @staticmethod
    def event(topic):
        return {"Records": [{"Sns": {"TopicArn": topic}}]}


if __name__ == "__main__":
    unittest.main()
