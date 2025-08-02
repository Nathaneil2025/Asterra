import json
import boto3
import os
import logging
from urllib.parse import unquote_plus

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ecs_client = boto3.client('ecs')

def lambda_handler(event, context):
    """
    Lambda function triggered by S3 events to process GeoJSON files
    """
    try:
        # Parse S3 event
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing S3 event: bucket={bucket_name}, key={object_key}")
            
            # Check if file is a GeoJSON file
            if not object_key.lower().endswith('.geojson'):
                logger.info(f"Skipping non-GeoJSON file: {object_key}")
                continue
            
            # Trigger ECS task
            response = trigger_ecs_task(bucket_name, object_key)
            logger.info(f"ECS task triggered successfully: {response}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Successfully triggered processing tasks')
        }
        
    except Exception as e:
        logger.error(f"Error processing S3 event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def trigger_ecs_task(bucket_name, object_key):
    """
    Trigger ECS Fargate task to process the GeoJSON file
    """
    cluster_name = os.environ['ECS_CLUSTER_NAME']
    task_definition = os.environ['ECS_TASK_DEFINITION']
    subnets = os.environ['ECS_SUBNETS'].split(',')
    security_groups = [os.environ['ECS_SECURITY_GROUPS']]
    
    # Prepare task overrides with file information
    container_overrides = [
        {
            'name': 'geojson-processor',
            'environment': [
                {
                    'name': 'S3_BUCKET',
                    'value': bucket_name
                },
                {
                    'name': 'S3_KEY',
                    'value': object_key
                }
            ]
        }
    ]
    
    # Run ECS task
    response = ecs_client.run_task(
        cluster=cluster_name,
        taskDefinition=task_definition,
        launchType='FARGATE',
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets': subnets,
                'securityGroups': security_groups,
                'assignPublicIp': 'DISABLED'  # Running in private subnet
            }
        },
        overrides={
            'containerOverrides': container_overrides
        }
    )
    
    return response