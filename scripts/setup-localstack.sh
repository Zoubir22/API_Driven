#!/bin/bash
# setup-localstack.sh - Script to install and start LocalStack

set -e

echo "🚀 Installing LocalStack..."

# Install pip if not available
if ! command -v pip3 &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y python3-pip
fi

# Install LocalStack
pip3 install --upgrade pip
pip3 install localstack awscli-local

# Set environment variables
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export S3_SKIP_SIGNATURE_VALIDATION=0

echo "✅ LocalStack installed successfully!"
echo ""
echo "📋 To start LocalStack, run: localstack start -d"
echo "📋 To check status, run: localstack status services"
echo ""
echo "⚠️  IMPORTANT: After starting LocalStack, set your AWS_ENDPOINT_URL:"
echo "    export AWS_ENDPOINT_URL=\$(localstack config show | grep -oP 'http://[^\"]+' | head -1)"
echo "    Or for GitHub Codespaces, use the public URL from the PORTS tab"
