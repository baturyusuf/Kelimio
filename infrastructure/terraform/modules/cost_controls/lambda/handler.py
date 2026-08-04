import json
import os

import boto3


ssm = boto3.client("ssm")
ec2 = boto3.client("ec2")
rds = boto3.client("rds")

MODE_RANK = {"NORMAL": 0, "CONSERVE": 1, "READ_ONLY": 2, "SUSPENDED": 3}


def _json_list(name: str) -> list[str]:
    value = json.loads(os.environ.get(name, "[]"))
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{name} must be a JSON string array")
    return value


def _stop_compute() -> dict[str, list[str]]:
    instance_ids = _json_list("EC2_INSTANCE_IDS")
    database_ids = _json_list("RDS_INSTANCE_IDENTIFIERS")
    stopped_instances: list[str] = []
    stopped_databases: list[str] = []

    if instance_ids:
        states = ec2.describe_instances(InstanceIds=instance_ids)
        running = [
            instance["InstanceId"]
            for reservation in states.get("Reservations", [])
            for instance in reservation.get("Instances", [])
            if instance.get("State", {}).get("Name") in {"pending", "running"}
        ]
        if running:
            ec2.stop_instances(InstanceIds=running)
            stopped_instances.extend(running)

    for database_id in database_ids:
        response = rds.describe_db_instances(DBInstanceIdentifier=database_id)
        databases = response.get("DBInstances", [])
        if databases and databases[0].get("DBInstanceStatus") == "available":
            rds.stop_db_instance(DBInstanceIdentifier=database_id)
            stopped_databases.append(database_id)

    return {"ec2": stopped_instances, "rds": stopped_databases}


def handler(event, _context):
    topic_modes = json.loads(os.environ["CONTROL_TOPIC_MODES"])
    topics = {
        record.get("Sns", {}).get("TopicArn")
        for record in event.get("Records", [])
    }
    if not topics or None in topics or not topics.issubset(topic_modes):
        raise ValueError("Budget notification came from an unrecognized topic")

    target_mode = max((topic_modes[topic] for topic in topics), key=MODE_RANK.__getitem__)
    parameter_name = os.environ["OPERATING_MODE_PARAMETER"]
    current_mode = ssm.get_parameter(Name=parameter_name)["Parameter"]["Value"]
    if current_mode not in MODE_RANK:
        target_mode = "SUSPENDED"
        current_mode = "NORMAL"

    changed = MODE_RANK[target_mode] > MODE_RANK[current_mode]
    effective_mode = target_mode if changed else current_mode
    if changed:
        ssm.put_parameter(
            Name=parameter_name,
            Value=target_mode,
            Type="String",
            Overwrite=True,
        )

    stopped = {"ec2": [], "rds": []}
    if effective_mode == "SUSPENDED":
        stopped = _stop_compute()

    # Budget messages can contain account and cost details. Do not echo the SNS
    # payload into logs; retain only the resulting bounded control action.
    result = {"mode": effective_mode, "changed": changed, "stopped": stopped}
    print(json.dumps(result, sort_keys=True))
    return result
