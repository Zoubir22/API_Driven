"""
Lambda function to control EC2 instances (start/stop)
This function is triggered via API Gateway
Compatible with LocalStack Docker environment - NO LOCALHOST DEPENDENCY
"""
import json
import boto3
import os

def get_ec2_client():
    """
    Create EC2 client configured for LocalStack.
    Uses LOCALSTACK_HOSTNAME which is automatically set by LocalStack
    when running Lambda functions inside its container.
    """
    # LocalStack automatically sets LOCALSTACK_HOSTNAME in Lambda environment
    localstack_host = os.environ.get('LOCALSTACK_HOSTNAME', 'localstack')
    endpoint = f"http://{localstack_host}:4566"
    
    return boto3.client(
        'ec2',
        endpoint_url=endpoint,
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )

def lambda_handler(event, context):
    """
    Main Lambda handler
    
    Expected event format:
    {
        "action": "start" | "stop" | "status",
        "instance_id": "i-xxxxx" (optional, uses default if not provided)
    }
    """
    try:
        # Parse request body if coming from API Gateway
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event
        
        action = body.get('action', 'status')
        instance_id = body.get('instance_id', os.environ.get('EC2_INSTANCE_ID'))
        
        if not instance_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'No instance_id provided and EC2_INSTANCE_ID not set'
                })
            }
        
        ec2 = get_ec2_client()
        
        if action == 'start':
            response = ec2.start_instances(InstanceIds=[instance_id])
            message = f"Instance {instance_id} is starting"
            state = response['StartingInstances'][0]['CurrentState']['Name']
            
        elif action == 'stop':
            response = ec2.stop_instances(InstanceIds=[instance_id])
            message = f"Instance {instance_id} is stopping"
            state = response['StoppingInstances'][0]['CurrentState']['Name']
            
        elif action == 'status':
            response = ec2.describe_instances(InstanceIds=[instance_id])
            state = response['Reservations'][0]['Instances'][0]['State']['Name']
            message = f"Instance {instance_id} is {state}"
            
        else:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': f"Invalid action: {action}. Use 'start', 'stop', or 'status'"
                })
            }
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': message,
                'instance_id': instance_id,
                'state': state,
                'action': action
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': str(e),
                'error_type': type(e).__name__
            })
        }
