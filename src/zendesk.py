# Python 3.X
import requests
import json
import hmac
import hashlib
import os
import time
import base64
from . import get_secrets

config = {
  'api_url': 'https://ustaxcourt.zendesk.com',
  'fields': {
    'bar_number': 360041870952,
    'docket_number': 360041668151,
    'email': 360041229971,
    'resolution': 7763063324941,
    'type': 7763059347085,
    'first_name': 8805054961549,
    'last_name': 8805008352653,
    'role': 8804894948877,
    'chambers': 8804991844749
  }
}

def get_env(): 
  secrets = get_secrets.get_secret()
  return {
    'user': secrets['ADMIN_USER'] + '/token',
    'token': secrets['API_TOKEN'],
    'admissions': secrets['ADMISSIONS_EMAILS'].split(','),
    'signing_secret': secrets['ZENDESK_SIGNING_SECRET'],
    'zendesk_group_id': secrets['ZENDESK_GROUP_ID']
  }

def set_custom_field_value(ticket, field_name, field_value):
  id = config['fields'][field_name]
  updated_fields = []

  for field in ticket['custom_fields']:
    if field['id'] != id:
      updated_fields.append(field)

  updated_fields.append({
    'id': id, 
    'value': field_value
  })
    
  ticket['custom_fields'] = updated_fields
  return ticket

def get_custom_field_value(fields, field_name):
  value = None
  id = config['fields'][field_name]

  for field in fields:
    if field['id'] == id:
      value = field['value']
  return value

def get_tickets_by_tag(tag_name):
  ''' 
  get all of the tickets in ZenDesk with the given `tag_name`
  '''
  env_vars = get_env()
  url = config['api_url'] + f'/api/v2/search.json?query=tags:{tag_name} group:' + env_vars['zendesk_group_id']
  response = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  return response.json()

def respond_and_keep_open(ticket_id, comment):
  '''
  respond to the ticket with the message, and keep it open
  '''
  payload = { 
    "ticket": {
      "status": "open",
      "comment": comment,
    }
  }
  update_ticket(ticket_id, payload)

def respond_and_mark_as_solved(ticket_id, comment):
  '''
  respond to the ticket with the message, and close it
  '''
  payload = { 
    "ticket": {
      "status": "solved",
      "comment": comment,
    }
  }
  update_ticket(ticket_id, payload)

def update_tags(ticket_id, tags):
  '''
  simply update the tags on the specified ticket.
  '''
  payload = { 
    "ticket": {
      "tags": tags,
    }
  }
  update_ticket(ticket_id, payload)

def update_ticket(ticket_id, payload):
  '''
  make api call to zendesk with the dict payload
  '''
  headers = {'Content-Type': 'application/json'}
  url = config['api_url'] + f'/api/v2/tickets/{ticket_id}'
  payload = json.dumps(payload)
  env_vars = get_env()
  resp = requests.put(url, data=payload, headers=headers, auth=(env_vars['user'], env_vars['token']))
  print(f'INFO: Ticket {ticket_id} updated in zendesk', resp)

def get_ticket(ticket_id):
  '''
  make api call to zendesk and get information about the ticket
  '''
  headers = {'Content-Type': 'application/json'}
  url = config['api_url'] + f'/api/v2/tickets/{ticket_id}'
  env_vars = get_env()
  resp = requests.get(url, headers=headers, auth=(env_vars['user'], env_vars['token']))
  return resp.json()

def get_all_groups():
  url = config['api_url'] + '/api/v2/groups'
  env_vars = get_env()
  resp = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  return resp.json()['groups']
  
def get_all_tags():
  url = config['api_url'] + '/api/v2/tags'
  env_vars = get_env()
  resp = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  return resp.json()

def is_ticket_from_admissions(ticket):
  '''
  determine whether or not this ticket originated from admissions
  '''
  if ticket['via']['channel'] != 'email':
    return False

  env_vars = get_env()
  ticket_email = ticket['via']['source']['from']['address'].lower()
  return ticket_email in env_vars['admissions']

def get_all_tickets(url=None, query=None):
  env_vars = get_env()
  if url == None:
    url = config['api_url'] + '/api/v2/search.json?query='
  
    if query == None:
      query = 'type:ticket status<solved'

    url = url + requests.utils.quote(query + ' group:' + str(env_vars['zendesk_group_id']))

  res = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  data = res.json()

  if 'next_page' in data and data['next_page'] is not None:
    more_data = get_all_tickets(data['next_page'])
    # return data['tickets']
    return data['results'] + more_data
  return data['results']

user_cache = {}
def get_user(user_id):
  if user_id is None:
    return 'Unassigned'

  user_id = str(user_id)

  if user_id not in user_cache:
    env_vars = get_env()
    url = config['api_url'] + f'/api/v2/users/{user_id}.json'
    resp = requests.get(url, auth=(env_vars['user'], env_vars['token']))
    data = resp.json()
    if 'user' in data and 'name' in data['user']:
      user_cache[user_id] = data['user']['name']
    else:
      raise Exception(f'Error fetching user {user_id}')

  return user_cache[user_id]

def handle_error(ticket, message):
  update_ticket(ticket_id=ticket['id'], payload={
    'ticket': {
      'comment': {
        'body': message,
        'public': False
      },
      'tags': ticket['tags']
    }
  })
  raise Exception(message)

def get_source_email(ticket):
  if ticket['via']['channel'] == 'email':
    return ticket['via']['source']['from']['address']
  return None

def verify_signature(body, signature, timestamp):
  env_vars = get_env()  
  calculated_signature = timestamp + body

  hash = hmac.new(
    env_vars['signing_secret'].encode('ascii'),
    calculated_signature.encode('ascii'),
    hashlib.sha256
  )

  generated_signature = base64.b64encode(hash.digest()).decode()
  return generated_signature == signature

def create_ticket(subject, body):
  env_vars = get_env()
  headers = {'Content-Type': 'application/json'}
  url = config['api_url'] + f'/api/v2/tickets/'
  payload = json.dumps({
    'ticket': {
      'comment': {
        'body': body,
      },
      'subject': subject,
      'group_id': env_vars['zendesk_group_id'],
      'via': {
        'channel': 'email',
        'source': {
          'from': {
            'address': 'petitioner2@example.com'
          }
        }
      }
    }
  })
  env_vars = get_env()
  resp = requests.post(url, data=payload, headers=headers, auth=(env_vars['user'], env_vars['token']))
  data = resp.json()
  ticket_id = data['ticket']['id']
  return str(ticket_id)

def get_ticket_comments(ticket_id):
  env_vars = get_env()
  url = config['api_url'] + f'/api/v2/tickets/{ticket_id}/comments'

  resp = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  data = resp.json()

  if 'comments' in data:
    return data['comments']
  return []

def delete_ticket(ticket_id):
  env_vars = get_env()
  url = config['api_url'] + f'/api/v2/tickets/{ticket_id}'
  requests.delete(url, auth=(env_vars['user'], env_vars['token']))

def get_user(assignee_id):
  env_vars = get_env()
  url = config['api_url'] + f'/api/v2/users/{assignee_id}.json'
  response = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  data = response.json()
  return data['user']['name']

def get_tickets_export(window_start, cursor):
  env_vars = get_env()
  url = config['api_url'] + f'/api/v2/incremental/tickets/cursor.json'
  if cursor is None:
    url = f'{url}?start_time={window_start}'
  else:
    url = f'{url}?cursor={cursor}'

  response = requests.get(url, auth=(env_vars['user'], env_vars['token']))

  if response.status_code == 429:
    print('rate limit reached. retry after: ', response.headers['Retry-After'])
    time.sleep(int(response.headers['Retry-After']) + 0.5)
    return get_tickets_export(window_start, cursor)
  else :
    data = response.json()
    return data

def get_ticket_metrics(ticket_id):
  print('get ticket metrics', ticket_id)
  env_vars = get_env()
  url = config['api_url'] + f'/api/v2/tickets/{ticket_id}/metrics'
  
  response = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  data = response.json()
  if 'ticket_metric' not in data:
    print('- could not find metric', ticket_id)
    return None
  else:
    return data['ticket_metric']

def get_ticket_field(field_name):
  ticket_field_id = config['fields'][field_name]
  env_vars = get_env()
  url = config['api_url'] + f'/api/v2/ticket_fields/{ticket_field_id}'
  response = requests.get(url, auth=(env_vars['user'], env_vars['token']))
  data = response.json()
  options = {}
  for option in data['ticket_field']['custom_field_options']:
    options[option['value']] = option['name']

  return options
  