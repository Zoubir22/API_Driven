#!/bin/bash
# create-infrastructure.sh - Create all AWS infrastructure on LocalStack

set -e

# Configuration - NO LOCALHOST DEPENDENCY
# AWS_ENDPOINT_URL MUST be set before running this script
if [ -z "$AWS_ENDPOINT_URL" ]; then
    echo "❌ ERROR: AWS_ENDPOINT_URL is not set!"
    echo ""
    echo "Please set your endpoint URL before running this script:"
    echo "  export AWS_ENDPOINT_URL=<your-localstack-url>"
    echo ""
    echo "Examples:"
    echo "  - GitHub Codespaces: https://your-codespace-4566.app.github.dev"
    echo "  - Local Docker: http://\$(docker inspect localstack-main --format '{{.NetworkSettings.IPAddress}}'):4566"
    exit 1
fi

ENDPOINT_URL="$AWS_ENDPOINT_URL"
REGION="us-east-1"
LAMBDA_NAME="ec2-controller"
API_NAME="ec2-api"

echo "🔧 AWS Endpoint: $ENDPOINT_URL"
echo ""

# Configure AWS CLI for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# Function to run AWS commands with LocalStack endpoint
aws_local() {
    aws --endpoint-url="$ENDPOINT_URL" "$@"
}

echo "📦 Step 1: Creating EC2 Instance..."
# Create a key pair first (required for EC2)
aws_local ec2 create-key-pair --key-name my-key 2>/dev/null || echo "Key pair already exists"

# Create a security group
SG_ID=$(aws_local ec2 create-security-group \
    --group-name my-sg \
    --description "Security group for API-Driven workshop" \
    --query 'GroupId' --output text 2>/dev/null || \
    aws_local ec2 describe-security-groups --group-names my-sg --query 'SecurityGroups[0].GroupId' --output text)
echo "   Security Group: $SG_ID"

# Run EC2 instance
INSTANCE_ID=$(aws_local ec2 run-instances \
    --image-id ami-12345678 \
    --instance-type t2.micro \
    --key-name my-key \
    --security-group-ids "$SG_ID" \
    --query 'Instances[0].InstanceId' --output text)
echo "   ✅ EC2 Instance created: $INSTANCE_ID"

# Save instance ID for later use
echo "$INSTANCE_ID" > /tmp/ec2_instance_id.txt

echo ""
echo "📦 Step 2: Creating Lambda Function..."

# Create Lambda execution role
ROLE_ARN=$(aws_local iam create-role \
    --role-name lambda-ec2-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    --query 'Role.Arn' --output text 2>/dev/null || \
    aws_local iam get-role --role-name lambda-ec2-role --query 'Role.Arn' --output text)
echo "   IAM Role: $ROLE_ARN"

# Package Lambda function using Python (avoids needing zip command)
cd "$(dirname "$0")/../lambda"
python3 -c "import zipfile; z = zipfile.ZipFile('/tmp/lambda_function.zip', 'w'); z.write('lambda_function.py'); z.close()"

# Create or update Lambda function
# Pass the endpoint URL as environment variable for Lambda to use
aws_local lambda create-function \
    --function-name $LAMBDA_NAME \
    --runtime python3.9 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb:///tmp/lambda_function.zip \
    --environment "Variables={EC2_INSTANCE_ID=$INSTANCE_ID}" \
    --timeout 30 2>/dev/null || \
    aws_local lambda update-function-code \
        --function-name $LAMBDA_NAME \
        --zip-file fileb:///tmp/lambda_function.zip
echo "   ✅ Lambda function created: $LAMBDA_NAME"

# Get Lambda ARN
LAMBDA_ARN=$(aws_local lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text)

echo ""
echo "📦 Step 3: Creating API Gateway..."

# Create REST API
API_ID=$(aws_local apigateway create-rest-api \
    --name $API_NAME \
    --description "API for controlling EC2 instances" \
    --query 'id' --output text)
echo "   API Gateway ID: $API_ID"

# Get root resource ID
ROOT_ID=$(aws_local apigateway get-resources --rest-api-id "$API_ID" --query 'items[0].id' --output text)

# Create /ec2 resource
EC2_RESOURCE_ID=$(aws_local apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$ROOT_ID" \
    --path-part "ec2" \
    --query 'id' --output text)
echo "   Resource /ec2: $EC2_RESOURCE_ID"

# Create POST method
aws_local apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$EC2_RESOURCE_ID" \
    --http-method POST \
    --authorization-type NONE

# Create Lambda integration
aws_local apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$EC2_RESOURCE_ID" \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

# Deploy API to 'prod' stage
aws_local apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name prod

echo "   ✅ API Gateway deployed!"

# Save API info
echo "$API_ID" > /tmp/api_gateway_id.txt

echo ""
echo "========================================"
echo "🎉 Infrastructure created successfully!"
echo "========================================"
echo ""
echo "📋 Summary:"
echo "   - EC2 Instance ID: $INSTANCE_ID"
echo "   - Lambda Function: $LAMBDA_NAME"
echo "   - API Gateway ID: $API_ID"
echo ""
echo "🔗 API Endpoint:"
echo "   $ENDPOINT_URL/restapis/$API_ID/prod/_user_request_/ec2"
echo ""
echo "📖 Usage examples:"
echo "   # Start EC2 instance"
echo "   curl -X POST $ENDPOINT_URL/restapis/$API_ID/prod/_user_request_/ec2 -d '{\"action\":\"start\"}'"
echo ""
echo "   # Stop EC2 instance"
echo "   curl -X POST $ENDPOINT_URL/restapis/$API_ID/prod/_user_request_/ec2 -d '{\"action\":\"stop\"}'"
echo ""
echo "   # Get status"
echo "   curl -X POST $ENDPOINT_URL/restapis/$API_ID/prod/_user_request_/ec2 -d '{\"action\":\"status\"}'"
