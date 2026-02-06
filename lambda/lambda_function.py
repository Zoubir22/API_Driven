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
    
    GET request: Returns welcome message with API documentation
    POST request: Executes action (start/stop/status)
    """
    try:
        # Handle GET requests (browser access)
        http_method = event.get('httpMethod', 'POST')
        
        if http_method == 'GET':
            instance_id = os.environ.get('EC2_INSTANCE_ID', 'unknown')
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'message': '🚀 API EC2 Controller - Bienvenue!',
                    'description': 'API pour contrôler les instances EC2 via LocalStack',
                    'instance_id': instance_id,
                    'endpoints': {
                        'status': 'POST avec {"action": "status"}',
                        'start': 'POST avec {"action": "start"}',
                        'stop': 'POST avec {"action": "stop"}'
                    },
                    'exemple': 'curl -X POST <url> -H "Content-Type: application/json" -d \'{"action":"status"}\''
                }, ensure_ascii=False, indent=2)
            }
        
        # Handle POST requests (API calls)
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
            message = f"✅ Instance {instance_id} démarrage en cours"
            state = response['StartingInstances'][0]['CurrentState']['Name']
            
        elif action == 'stop':
            response = ec2.stop_instances(InstanceIds=[instance_id])
            message = f"⏹️ Instance {instance_id} arrêt en cours"
            state = response['StoppingInstances'][0]['CurrentState']['Name']
            
        elif action == 'status':
            response = ec2.describe_instances(InstanceIds=[instance_id])
            state = response['Reservations'][0]['Instances'][0]['State']['Name']
            if state == 'running':
                message = f"🟢 Instance {instance_id} est en cours d'exécution"
            elif state == 'stopped':
                message = f"🔴 Instance {instance_id} est arrêtée"
            else:
                message = f"🟡 Instance {instance_id} est en état: {state}"
            
        else:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': f"Action invalide: {action}. Utilisez 'start', 'stop', ou 'status'"
                })
            }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': message,
                'instance_id': instance_id,
                'state': state,
                'action': action
            }, ensure_ascii=False)
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
