import json
import os
import time
import uuid

import boto3


ssm = boto3.client("ssm")
ec2 = boto3.client("ec2")
rds = boto3.client("rds")
ecs = boto3.client("ecs")
dynamodb = boto3.client("dynamodb")
sns = boto3.client("sns")

MODE_RANK = {"NORMAL": 0, "CONSERVE": 1, "READ_ONLY": 2, "SUSPENDED": 3}
LOCK_NAME = "cost-governor"
LOCK_LEASE_SECONDS = 90


def _conditional_failure(error: Exception) -> bool:
    response = getattr(error, "response", {})
    return response.get("Error", {}).get("Code") == "ConditionalCheckFailedException"


def _acquire_lock(context) -> str:
    owner_id = getattr(context, "aws_request_id", None) or str(uuid.uuid4())
    now = int(time.time())
    try:
        dynamodb.put_item(
            TableName=os.environ["GOVERNOR_LOCK_TABLE"],
            Item={
                "lock_name": {"S": LOCK_NAME},
                "owner_id": {"S": owner_id},
                "expires_at": {"N": str(now + LOCK_LEASE_SECONDS)},
            },
            ConditionExpression="attribute_not_exists(lock_name) OR expires_at < :now",
            ExpressionAttributeValues={":now": {"N": str(now)}},
        )
    except Exception as error:
        if _conditional_failure(error):
            raise RuntimeError("Cost governor serialization lease is busy") from error
        raise
    return owner_id


def _release_lock(owner_id: str) -> None:
    try:
        dynamodb.delete_item(
            TableName=os.environ["GOVERNOR_LOCK_TABLE"],
            Key={"lock_name": {"S": LOCK_NAME}},
            ConditionExpression="owner_id = :owner_id",
            ExpressionAttributeValues={":owner_id": {"S": owner_id}},
        )
    except Exception as error:
        if _conditional_failure(error):
            print(json.dumps({"lock_release": "ownership_lost"}, sort_keys=True))
            return
        raise


def _json_list(name: str) -> list[str]:
    value = json.loads(os.environ.get(name, "[]"))
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{name} must be a JSON string array")
    return value


def _stop_compute() -> dict[str, list[str]]:
    instance_ids = _json_list("EC2_INSTANCE_IDS")
    database_ids = _json_list("RDS_INSTANCE_IDENTIFIERS")
    ecs_services = json.loads(os.environ.get("ECS_SERVICES", "[]"))
    if not isinstance(ecs_services, list) or not all(
        isinstance(item, dict)
        and isinstance(item.get("cluster"), str)
        and isinstance(item.get("service"), str)
        for item in ecs_services
    ):
        raise ValueError("ECS_SERVICES must be a JSON array of cluster/service objects")
    stopped_instances: list[str] = []
    stopped_databases: list[str] = []
    stopped_services: list[str] = []

    for item in ecs_services:
        response = ecs.describe_services(cluster=item["cluster"], services=[item["service"]])
        services = response.get("services", [])
        if services and services[0].get("desiredCount", 0) > 0:
            ecs.update_service(cluster=item["cluster"], service=item["service"], desiredCount=0)
            stopped_services.append(f'{item["cluster"]}/{item["service"]}')

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

    return {"ec2": stopped_instances, "ecs": stopped_services, "rds": stopped_databases}


def _handle(event):
    parameter_name = os.environ["OPERATING_MODE_PARAMETER"]
    current_mode = ssm.get_parameter(Name=parameter_name)["Parameter"]["Value"]
    allow_monthly_reset = False
    budget_notification = event.get("source") != "aws.events"
    if current_mode not in MODE_RANK:
        current_mode = "NORMAL"
        target_mode = "SUSPENDED"
    elif event.get("source") == "aws.events":
        action = event.get("action", "reassert-suspension")
        if action == "reassert-suspension":
            target_mode = current_mode
        elif action == "reset-new-budget-month":
            target_mode = "NORMAL"
            allow_monthly_reset = True
        else:
            raise ValueError("Cost governor received an unrecognized scheduled action")
    else:
        topic_modes = json.loads(os.environ["CONTROL_TOPIC_MODES"])
        topics = {
            record.get("Sns", {}).get("TopicArn")
            for record in event.get("Records", [])
        }
        if not topics or None in topics or not topics.issubset(topic_modes):
            raise ValueError("Budget notification came from an unrecognized topic")
        target_mode = max((topic_modes[topic] for topic in topics), key=MODE_RANK.__getitem__)

    changed = (
        target_mode != current_mode
        if allow_monthly_reset
        else MODE_RANK[target_mode] > MODE_RANK[current_mode]
    )
    effective_mode = target_mode if changed else current_mode
    if changed:
        ssm.put_parameter(
            Name=parameter_name,
            Value=target_mode,
            Type="String",
            Overwrite=True,
        )

    stopped = {"ec2": [], "ecs": [], "rds": []}
    if effective_mode == "SUSPENDED":
        stopped = _stop_compute()

    # Budget messages can contain account and cost details. Do not echo the SNS
    # payload into logs; retain only the resulting bounded control action.
    result = {"mode": effective_mode, "changed": changed, "stopped": stopped}
    print(json.dumps(result, sort_keys=True))
    if budget_notification:
        sns.publish(
            TopicArn=os.environ["OPERATIONS_TOPIC_ARN"],
            Subject="Kelimio cost governor",
            Message=json.dumps(result, sort_keys=True),
        )
    return result


def handler(event, context):
    owner_id = _acquire_lock(context)
    try:
        return _handle(event)
    finally:
        _release_lock(owner_id)
