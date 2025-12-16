from . import zendesk
from . import aws
from . import db
from datetime import date, datetime
import time
import json
import os
from botocore.exceptions import ClientError
import re
from calendar import monthrange

field_value_cache = {}
cached_cursor = None

def get_field_value(field_name, key):
  if key == 'None' or key == '':
    return 'None'

  if field_name not in field_value_cache:
    field_value_cache[field_name] = zendesk.get_ticket_field(field_name)
  
  return field_value_cache[field_name][key]

def update_ticket_in_database(ticket):
  '''
  update json in s3
  '''
  # get metrics for ticket, and inject current status into metrics
  metrics = zendesk.get_ticket_metrics(ticket['id'])
  if metrics is None:
    return

  metrics['status'] = ticket['status']
  metrics['type'] = zendesk.get_custom_field_value(ticket['custom_fields'], 'type')
  metrics['resolution'] = zendesk.get_custom_field_value(ticket['custom_fields'], 'resolution')
  metrics['is_public_helpdesk'] = True if 'public-helpdesk' in ticket['tags'] else False

  client = aws.get_s3_client()
  bucket = os.getenv('METRICS_BUCKET')
  metrics_json = json.dumps(metrics)
  ticket_id_padded = str(ticket['id']).rjust(7, "0")

  client.put_object(
    Body=metrics_json,
    Bucket=bucket,
    Key=f'tickets/{ticket_id_padded}.json',
    ContentType='application/json',
  )
  print(f'saved {ticket_id_padded} to s3')

def update_metrics_database_at_cursor(window_start, cursor):
  data = zendesk.get_tickets_export(window_start, cursor)
  env_vars = zendesk.get_env()

  for ticket in data['tickets']:
    if ticket['group_id'] is None:
      print('ticket is not a dawson ticket: None; ' + str(ticket['id']))
      continue
    elif int(ticket['group_id']) != int(env_vars['zendesk_group_id']):
      print('ticket is not a dawson ticket: ' + str(ticket['group_id']) + '; ' + str(ticket['id']))
      continue

    insert_item_into_queue('update_ticket', ticket)

  print('next cursor (saving for next time): ', data['after_cursor'])
  update_metrics_cursor(data['after_cursor'])

  if data['end_of_stream'] == False:
    print('continuing at ', data['after_cursor'])
    params = { 
      'window_start': window_start, 
      'cursor': data['after_cursor'],
      'source': 'sqs-message' 
    }
    return insert_item_into_queue('update_database', params)
  
  print('DONE')
  clear_cache()
  build_cache_populate_queue()

def update_metrics_database(event, context):
  print('update_metrics_database from lambda')
  cursor = get_metrics_cursor(use_cache=False)
  window_start = datetime.strptime('01/01/2021', '%m/%d/%Y')
  window_start = int(time.mktime(window_start.timetuple()))
  params = { 
    'window_start': window_start, 
    'cursor': cursor, 
    'source': 'cron' 
  }
  insert_item_into_queue('update_database', params)
  # update_metrics_database_at_cursor(window_start, cursor)

def process_sqs_message(event, context):
  print('process_sqs_message lambda entry, record count: ', len(event['Records']))
  for record in event['Records']:
    print('processing message')
    body = record['body']
    try:
      body = json.loads(body)
      job = body['job']
      params = body['params']
      print('job', job, 'params', params)

      if job == 'solved': 
        get_solved_metrics(
          params['year'], 
          params['month']
        )
      elif job == 'created':
        get_created_metrics(
          params['year'], 
          params['month']
        )
      elif job == 'update_database':
        update_metrics_database_at_cursor(
          params['window_start'], 
          params['cursor']
        )
      elif job == 'update_ticket':
        update_ticket_in_database(params)
      else:
        raise Exception(f"Unknown job type: {job}")

    except Exception as e:
      print(f"Error processing message: {e}")
      # return {"statusCode": 400, "body": "Error processing message"}
      raise Exception(e)
    return {"statusCode": 200}

def insert_item_into_queue(job, params):
  print('inserting item into queue, job', job, 'params', params)
  client = aws.get_sqs_client()
  queue_url = os.getenv('JOB_QUEUE_URL')
  client.send_message(
    QueueUrl=queue_url,
    MessageBody=json.dumps({
      'job': job,
      'params': params,
    }),
  )
  print('done inserting into queue')

def build_cache_populate_queue():
  today = date.today()
  current_year = today.year
  current_month = today.month
  for year in range(2021, current_year + 1):
    params = {
      'year': year,
      'month': None
    }
    # build cache for each year for created tickets, but no need for solved because it doesn't perform a query
    insert_item_into_queue('created', params)

    for month in range(1, 13):
      if year == current_year and month > current_month:
        return
      
      params['month'] = month

      # build cache for each month of the year for solved and created
      insert_item_into_queue('solved', params)
      insert_item_into_queue('created', params)

def update_metrics_cursor(new_cursor):
  global cached_cursor
  client = aws.get_s3_client()
  client.put_object(
    Body=new_cursor,
    Bucket=os.getenv('METRICS_BUCKET'),
    Key='config/zendesk-cursor.txt',
  )
  cached_cursor = new_cursor

def get_metrics_cursor(use_cache=True):
  global cached_cursor
  if cached_cursor is not None and use_cache:
    return cached_cursor

  try: 
    client = aws.get_s3_client()
    response = client.get_object(
      Bucket=os.getenv('METRICS_BUCKET'),
      Key='config/zendesk-cursor.txt',
    )
    cached_cursor = response['Body'].read().decode('utf-8')
    return cached_cursor
  except client.exceptions.NoSuchKey:
    return None

def get_all_unsolved():
  query = "SELECT COUNT(ticket_id) FROM dawson_tickets2 WHERE status != 'closed' AND status != 'solved'"

  # query = 'status<solved type:ticket'
  # total_unsolved = zendesk.get_all_tickets(None, query)
  # counts = {
  #   'assignee': {},
  #   'total': len(total_unsolved),
  # }
  # for ticket in total_unsolved:
  #   #assignee
  #   assignee = get_assignee(ticket['assignee_id'])
  #   if assignee not in counts['assignee']:
  #     counts['assignee'][assignee] = 0
  #   counts['assignee'][assignee]+=1
  return

def get_report(event, context):
  print('debug', json.dumps(event['queryStringParameters']))

  if 'year' not in event['queryStringParameters']:
    return {
      "statusCode": 400,
      "body": f"Incorrect format of year: {year}"
    }
  year = event['queryStringParameters']['year']
  if len(year) != 4 or year.isdigit() == False:
    return {
      "statusCode": 400,
      "body": f"Incorrect format of year: {year}"
    }
  
  month = None
  if 'month' in event['queryStringParameters']:
    month = event['queryStringParameters']['month']

  data = {
    'created': get_created_metrics(year, month),
    'solved': get_solved_metrics(year, month),
  }

  return {
    "statusCode": 200,
    "body": json.dumps(data)
  }

def get_types_solved_by_month(year, month):
  cache_key = 'types_solved_by_month'
  counts = check_cache(cache_key, year, month)
  if counts is not None:
    return counts
  
  counts = {}
  keys, data = db.query(
    f"SELECT COUNT(ticket_id) AS num_tickets, type FROM zendesk_tickets WHERE year(solved_at) = {year} AND month(solved_at) = {month} AND type != '' GROUP BY type"
  )

  for row in data:
    ticket_type = get_field_value('type', row['type'])
    counts[ticket_type] = row['num_tickets']
  
  save_cache(cache_key, year, month, counts)
  return counts

def get_resolutions_solved_by_month(year, month):
  cache_key = 'resolutions_solved_by_month'
  counts = check_cache(cache_key, year, month)
  if counts is not None:
    return counts
  
  counts = {
    'types': {},
    'resolutions': {},
    'resolutions_by_type': {}
  }
  keys, data = db.query((    
    f"SELECT COUNT(ticket_id) AS num_tickets, type_resolution FROM (SELECT ticket_id, CONCAT(type, '::::', resolution) AS type_resolution FROM zendesk_tickets WHERE year(solved_at) = {year} AND month(solved_at) = {month} AND type != '' AND resolution != '') GROUP BY type_resolution"
  ))

  for row in data:
    ticket_type = get_field_value('type', row['type_resolution'].split('::::')[0])
    ticket_resolution = get_field_value('resolution', row['type_resolution'].split('::::')[1])
    num_tickets = int(row['num_tickets'])

    if ticket_type not in counts['types']:
      counts['types'][ticket_type] = 0
    counts['types'][ticket_type] += num_tickets

    if ticket_resolution not in counts['resolutions']:
      counts['resolutions'][ticket_resolution] = 0
    counts['resolutions'][ticket_resolution] += num_tickets

    if ticket_type not in counts['resolutions_by_type']:
      counts['resolutions_by_type'][ticket_type] = {}

    counts['resolutions_by_type'][ticket_type][ticket_resolution] = num_tickets

  save_cache(cache_key, year, month, counts)
  return counts

def build_dataset(item, item_key, annual_data):
  data = []
  for month_data in annual_data:
    if item in month_data[item_key]:
      data.append(month_data[item_key][item])
    else:
      data.append(0)

  return data

def get_solved_metrics(year, month):
  if month is not None:
    return get_resolutions_solved_by_month(year, month)

  # this will create ready-made datasets for the types and resolutions to return
  counts = {
    'types': [],
    'resolutions': [],
  }

  # this will key a list of all types and resolutions that will appear in the report
  scope = {
    'types': [],
    'resolutions': []
  }

  annual_data = []
  for month_to_query in range(12):

    month_data = get_resolutions_solved_by_month(year, month_to_query+1)
    annual_data.append(month_data)

    for k in scope:
      for item in month_data[k]:
        if item not in scope[k]:
          scope[k].append(item)
  
  for k in scope:
    for item in scope[k]:
      dataset = build_dataset(item, k, annual_data)
      counts[k].append({
        'label': item,
        'data': dataset
      })

  return counts

def get_cache_filename(report, year, month):
  cursor = get_metrics_cursor()
  if month is None:
    return f'cache/{cursor}/{report}-{year}.json'
  else:
    return f'cache/{cursor}/{report}-{year}-{month}.json'

def check_cache(report, year, month):
  client = aws.get_s3_client()
  cache_filename = get_cache_filename(report, year, month)
  try:
    response = client.get_object(
      Bucket=os.getenv('METRICS_BUCKET'),
      Key=cache_filename,
    )
    return json.loads(response['Body'].read().decode('utf-8'))
  except client.exceptions.NoSuchKey:
    return None

def save_cache(report, year, month, data):
  client = aws.get_s3_client()
  cache_filename = get_cache_filename(report, year, month)
  client.put_object(
    Bucket=os.getenv('METRICS_BUCKET'),
    Key=cache_filename,
    Body=json.dumps(data),
    ContentType='application/json',
  )

def clear_cache():
  client = aws.get_s3_client()
  bucket = os.getenv('METRICS_BUCKET')
  response = client.list_objects(
    Bucket=bucket,
    MaxKeys=1000,
    Prefix='cache/'
  )
  keys = []
  if 'Contents' not in response:
    return

  for object in response['Contents']:
    keys.append({'Key': object['Key']})
  
  client.delete_objects(
    Bucket=bucket,
    Delete={
      'Objects': keys
    }
  )

  if response['IsTruncated'] is True:
    clear_cache()

def get_created_metrics_by_year(year):
  cache_key = 'created'
  counts = check_cache(cache_key, year, None)
  if counts is not None:
    return counts

  keys, data = db.query((    
    f"SELECT count(ticket_id) AS num_tickets, month_created from (SELECT ticket_id, month(created_at) as month_created FROM zendesk_tickets WHERE year(created_at) = {year}) GROUP BY month_created ORDER BY month_created"
  ))
  counts = {}
  
  for row in data:
    counts[row['month_created']] = row['num_tickets']

  for month in range(12):
    if str(month+1) not in counts:
      counts[str(month+1)] = 0

  save_cache(cache_key, year, None, counts)
  return counts

def get_created_metrics_by_month(year, month):
  cache_key = 'created'
  counts = check_cache(cache_key, year, month)
  if counts is not None:
    return counts

  # this gets all tickets
  last_day_of_month = monthrange(int(year), int(month))[1]
  keys, data = db.query((
    'SELECT count(ticket_id) AS num_tickets, date_created from ('
    "SELECT ticket_id, day_of_month(created_at) AS date_created "
    f'FROM zendesk_tickets WHERE year(created_at)={year} AND month(created_at)={month}) '
    'GROUP BY date_created ORDER BY date_created'
  ))
  counts = {}
  for row in data:
    key = row['date_created']
    counts[key] = {
      'total': int(row['num_tickets']),
      'dawson': 0,
      'helpdesk': 0
    }

  for day in range(1, last_day_of_month+1):
    day_of_month = str(day)
    if day_of_month not in counts:
      counts[day_of_month] = { 'total': 0, 'dawson': 0, 'helpdesk': 0 }

  # this gets tickets for public helpdesk for final count calculation
  keys, data = db.query((
    'SELECT count(ticket_id) AS num_tickets, date_created from ('
    "SELECT ticket_id, day_of_month(created_at) AS date_created "
    f'FROM zendesk_tickets WHERE year(created_at)={year} AND month(created_at)={month} AND is_public_helpdesk = false) '
    'GROUP BY date_created ORDER BY date_created'
  ))

  days_found = []
  for row in data:
    days_found.append(key)
    key = row['date_created']
    num_dawson_tickets = int(row['num_tickets'])
    counts[key]['dawson'] = num_dawson_tickets
    counts[key]['helpdesk'] = counts[key]['total'] - num_dawson_tickets

  for day in range(1, last_day_of_month+1):
    day_of_month = str(day)
    if day_of_month not in days_found:
      counts[day_of_month]['helpdesk'] = 0
      counts[day_of_month]['dawson'] = counts[day_of_month]['total']

  save_cache(cache_key, year, month, counts)
  return counts

def get_created_metrics(year, month):
  if month is None:
    return get_created_metrics_by_year(year)
  else:
    return get_created_metrics_by_month(year, month)
