import boto3 

def get_cognito_client():
  return boto3.client('cognito-idp', region_name="us-east-1")

def get_dynamodb():
  return boto3.resource('dynamodb', region_name="us-east-1")

def get_session():
  return boto3.session.Session()

def get_ses_client():
  return boto3.client("ses", region_name="us-east-1")

def get_sesv2_client():
  return boto3.client("sesv2", region_name="us-east-1")

def get_s3_client():
  return boto3.client('s3', region_name="us-east-1")

def get_athena_client():
  return boto3.client('athena', region_name="us-east-1")
