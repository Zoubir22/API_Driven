#!/usr/bin/env python3
"""
create-infrastructure.py - Create all AWS infrastructure on LocalStack
Uses boto3 directly to avoid aws CLI path issues in Codespaces
"""

import boto3
import json
import os
import sys
import zipfile
import time

# Configuration
ENDPOINT_URL = os.environ.get('AWS_ENDPOINT_URL')
REGION = 'us-east-1'
LAMBDA_NAME = 'ec2-controller'
API_NAME = 'ec2-api'

if not ENDPOINT_URL:
    print("❌ ERROR: AWS_ENDPOINT_URL is not set!")
    print("")
    print("Please set your endpoint URL before running this script:")
    print("  export AWS_ENDPOINT_URL=<your-localstack-url>")
    sys.exit(1)

# Remove trailing slash if present
ENDPOINT_URL = ENDPOINT_URL.rstrip('/')

print(f"🔧 AWS Endpoint: {ENDPOINT_URL}")
print("")

# Create boto3 clients
def get_client(service):
    return boto3.client(
        service,
        endpoint_url=ENDPOINT_URL,
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name=REGION
    )

ec2 = get_client('ec2')
iam = get_client('iam')
lambda_client = get_client('lambda')
apigateway = get_client('apigateway')

# Step 1: Create EC2 Instance
print("📦 Step 1: Creating EC2 Instance...")

try:
    ec2.create_key_pair(KeyName='my-key')
    print("   Key pair created")
except Exception as e:
    print("   Key pair already exists")

try:
    sg_response = ec2.create_security_group(
        GroupName='my-sg',
        Description='Security group for API-Driven workshop'
    )
    SG_ID = sg_response['GroupId']
except Exception as e:
    sg_response = ec2.describe_security_groups(GroupNames=['my-sg'])
    SG_ID = sg_response['SecurityGroups'][0]['GroupId']
print(f"   Security Group: {SG_ID}")

instance_response = ec2.run_instances(
    ImageId='ami-12345678',
    InstanceType='t2.micro',
    KeyName='my-key',
    SecurityGroupIds=[SG_ID],
    MinCount=1,
    MaxCount=1
)
INSTANCE_ID = instance_response['Instances'][0]['InstanceId']
print(f"   ✅ EC2 Instance created: {INSTANCE_ID}")

# Save instance ID
with open('/tmp/ec2_instance_id.txt', 'w') as f:
    f.write(INSTANCE_ID)

# Step 2: Create Lambda Function
print("")
print("📦 Step 2: Creating Lambda Function...")

# Create IAM role
try:
    role_response = iam.create_role(
        RoleName='lambda-ec2-role',
        AssumeRolePolicyDocument=json.dumps({
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        })
    )
    ROLE_ARN = role_response['Role']['Arn']
except Exception as e:
    role_response = iam.get_role(RoleName='lambda-ec2-role')
    ROLE_ARN = role_response['Role']['Arn']
print(f"   IAM Role: {ROLE_ARN}")

# Create Lambda ZIP
script_dir = os.path.dirname(os.path.abspath(__file__))
lambda_dir = os.path.join(script_dir, '..', 'lambda')
zip_path = '/tmp/lambda_function.zip'

with zipfile.ZipFile(zip_path, 'w') as z:
    z.write(os.path.join(lambda_dir, 'lambda_function.py'), 'lambda_function.py')

# Create or update Lambda
with open(zip_path, 'rb') as f:
    zip_content = f.read()

try:
    lambda_client.create_function(
        FunctionName=LAMBDA_NAME,
        Runtime='python3.9',
        Role=ROLE_ARN,
        Handler='lambda_function.lambda_handler',
        Code={'ZipFile': zip_content},
        Environment={'Variables': {'EC2_INSTANCE_ID': INSTANCE_ID}},
        Timeout=30
    )
except Exception as e:
    lambda_client.update_function_code(
        FunctionName=LAMBDA_NAME,
        ZipFile=zip_content
    )
print(f"   ✅ Lambda function created: {LAMBDA_NAME}")

# Get Lambda ARN
lambda_response = lambda_client.get_function(FunctionName=LAMBDA_NAME)
LAMBDA_ARN = lambda_response['Configuration']['FunctionArn']

# Step 3: Create API Gateway
print("")
print("📦 Step 3: Creating API Gateway...")

# Create REST API
api_response = apigateway.create_rest_api(
    name=API_NAME,
    description='API for controlling EC2 instances'
)
API_ID = api_response['id']
print(f"   API Gateway ID: {API_ID}")

# Get root resource
resources = apigateway.get_resources(restApiId=API_ID)
ROOT_ID = resources['items'][0]['id']

# Create /ec2 resource
resource_response = apigateway.create_resource(
    restApiId=API_ID,
    parentId=ROOT_ID,
    pathPart='ec2'
)
EC2_RESOURCE_ID = resource_response['id']
print(f"   Resource /ec2: {EC2_RESOURCE_ID}")

# Create POST method
apigateway.put_method(
    restApiId=API_ID,
    resourceId=EC2_RESOURCE_ID,
    httpMethod='POST',
    authorizationType='NONE'
)

# Create Lambda integration
apigateway.put_integration(
    restApiId=API_ID,
    resourceId=EC2_RESOURCE_ID,
    httpMethod='POST',
    type='AWS_PROXY',
    integrationHttpMethod='POST',
    uri=f'arn:aws:apigateway:{REGION}:lambda:path/2015-03-31/functions/{LAMBDA_ARN}/invocations'
)

# Deploy API
apigateway.create_deployment(
    restApiId=API_ID,
    stageName='prod'
)
print("   ✅ API Gateway deployed!")

# Save API ID
with open('/tmp/api_gateway_id.txt', 'w') as f:
    f.write(API_ID)

print("")
print("========================================")
print("🎉 Infrastructure created successfully!")
print("========================================")
print("")
print("📋 Summary:")
print(f"   - EC2 Instance ID: {INSTANCE_ID}")
print(f"   - Lambda Function: {LAMBDA_NAME}")
print(f"   - API Gateway ID: {API_ID}")
print("")
print("🔗 API Endpoint:")
print(f"   {ENDPOINT_URL}/restapis/{API_ID}/prod/_user_request_/ec2")
print("")
print("📖 Usage examples:")
print(f'   curl -X POST {ENDPOINT_URL}/restapis/{API_ID}/prod/_user_request_/ec2 -d \'{{"action":"start"}}\'')
print(f'   curl -X POST {ENDPOINT_URL}/restapis/{API_ID}/prod/_user_request_/ec2 -d \'{{"action":"stop"}}\'')
print(f'   curl -X POST {ENDPOINT_URL}/restapis/{API_ID}/prod/_user_request_/ec2 -d \'{{"action":"status"}}\'')
