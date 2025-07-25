# lambda_function.py

import boto3
from datetime import datetime, timezone
import os

ec2 = boto3.client('ec2')
sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    now = datetime.now(timezone.utc)
    response = ec2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])

    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            launch_time = instance['LaunchTime']
            run_minutes = (now - launch_time).total_seconds() / 60

            if run_minutes > 30:
                instance_id = instance['InstanceId']
                msg = f"⚠️ EC2 Instance {instance_id} has been running for {int(run_minutes)} minutes."
                sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="EC2 Instance Runtime Alert",
                    Message=msg
                )
