# Use this code snippet in your app.
# If you need more information about configurations or implementing the sample code, visit the AWS docs:   
# https://aws.amazon.com/developers/getting-started/python/

import base64
from botocore.exceptions import ClientError
import json
import os
from . import aws

secret_cache = {}
ENV = os.getenv('ENV')

def get_secret():
  if ENV == 'development':
    return {
      'ADMIN_USER': 'some-admin@example.com',
      'ADMIN_PASS': 'Passw0rd#',
      'USTC_ADMIN_USER': 'some-admin@example.com',
      'USTC_ADMIN_PASS': 'Passw0rd#',
      'USTC_ZENDESK_USER': 'some-zendesk@example.com',
      'USTC_ZENDESK_PASS': 'Passw0rd#',
      'API_TOKEN': 'token-123',
      'ADMISSIONS_EMAILS': 'admissions1@example.com,admissions2@example.com',
      'ZENDESK_SIGNING_SECRET': 'dGhpc19zZWNyZXRfaXNfZm9yX3Rlc3Rpbmdfb25seQ==' # this was real, but it has been rotated
    }

  secret_name = "ZendeskDawson"
  region_name = "us-east-1"
  
  if secret_name in secret_cache.keys():
    return secret_cache[secret_name]

  # Create a Secrets Manager client
  session = aws.get_session()
  client = session.client(
    service_name='secretsmanager',
    region_name=region_name
  )

  # In this sample we only handle the specific exceptions for the 'GetSecretValue' API.
  # See https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
  # We rethrow the exception by default.

  try:
    get_secret_value_response = client.get_secret_value(
      SecretId=secret_name
    )
  except ClientError as e:
    if e.response['Error']['Code'] == 'DecryptionFailureException':
      # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'InternalServiceErrorException':
      # An error occurred on the server side.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'InvalidParameterException':
      # You provided an invalid value for a parameter.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'InvalidRequestException':
      # You provided a parameter value that is not valid for the current state of the resource.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'ResourceNotFoundException':
      # We can't find the resource that you asked for.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    else:
      raise e
  else:
    # Decrypts secret using the associated KMS CMK.
    # Depending on whether the secret is a string or binary, one of these fields will be populated.
    if 'SecretString' in get_secret_value_response:
      secret = json.loads(get_secret_value_response['SecretString'])
      secret_cache[secret_name] = secret
      return secret
    else:
      decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
      secret_cache[secret_name] = json.loads(decoded_binary_secret)
      return decoded_binary_secret
