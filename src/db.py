from . import aws
import time

athena_results_bucket = os.getenv('ATHENA_RESULTS_BUCKET')


def query(QueryString):
  client = aws.get_athena_client()
  response = client.start_query_execution(
    QueryString=QueryString,
    QueryExecutionContext={
        'Database': 'zendesk_tickets'
    },
     ResultConfiguration={
        'OutputLocation': f's3://${results_location}/',
        },
    WorkGroup='primary'
  )

  queryExecutionId = response['QueryExecutionId']

  response = client.get_query_execution(QueryExecutionId=queryExecutionId)

  i = 0
  while response['QueryExecution']['Status']['State'] in ['QUEUED','RUNNING']:
    response = client.get_query_execution(QueryExecutionId=queryExecutionId)
    # time.sleep(math.pow(2, i))
    time.sleep(1)
    print(response)
    i+=1

  if response['QueryExecution']['Status']['State'] == 'SUCCEEDED':
    response = client.get_query_results(
      QueryExecutionId=queryExecutionId,
      # MaxResults=2000
    )
    data = []
    keys = []
    i = 0
    print(response['ResultSet']['Rows'])
    for row in response['ResultSet']['Rows']:
      if i == 0:
        for col in row['Data']:
          keys.append(col['VarCharValue'])
      else:
        row_data = {}
        j = 0
        for col in row['Data']:
          if 'VarCharValue' in col:
            row_data[keys[j]] = col['VarCharValue']
          else:
            row_data[keys[j]] = 'None'

          j+=1
        data.append(row_data)
      i+=1

    return keys, data
  raise Exception(response['QueryExecution'])
