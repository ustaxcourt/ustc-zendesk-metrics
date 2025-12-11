from src import metrics

def get_report_handler(event, context):
  return metrics.get_report(event, context)

def update_metrics_database_handler(event, context):
  print('update_metrics_database_handler lambda entry')
  return metrics.update_metrics_database(event, context)

def process_sqs_message_handler(event, context):
  return metrics.process_sqs_message(event, context)
