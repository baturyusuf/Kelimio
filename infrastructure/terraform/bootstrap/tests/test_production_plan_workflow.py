import pathlib
import unittest


class ProductionPlanWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        repository_root = pathlib.Path(__file__).resolve().parents[4]
        cls.workflow = (repository_root / ".github/workflows/production-plan.yml").read_text(
            encoding="utf-8"
        )

    def test_all_required_immutable_images_are_supplied(self):
        for variable in (
            "TF_VAR_api_image_digest",
            "TF_VAR_worker_image_digest",
            "TF_VAR_scanner_image_digest",
        ):
            self.assertIn(variable, self.workflow)

    def test_teacher_feature_state_is_planned_explicitly(self):
        self.assertIn("TF_VAR_production_teacher_features_enabled", self.workflow)


if __name__ == "__main__":
    unittest.main()
