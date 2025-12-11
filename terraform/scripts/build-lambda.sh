#!/bin/bash

# Build script for Lambda deployment

set -e

echo "Building Lambda functions for deployment..."

# Change to project root directory
cd "$(dirname "$0")/../.."

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf ./dist
rm -f terraform/lambda-deployment.zip

mkdir dist

# Install dependencies if node_modules doesn't exist
cp -r ./src ./dist
pip3 install --target ./dist -r requirements.txt
cp ./lambda_handler.py ./dist

cd dist
zip -r  ../terraform/lambda-deployment.zip .
cd ..
