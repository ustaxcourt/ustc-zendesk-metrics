from unittest import mock
import src.metrics

def test_get_report():
  with mock.patch('src.metrics.get_solved_metrics') as mock_get_solved_metrics:
    with mock.patch('src.metrics.get_created_metrics') as mock_get_created_metrics:
      event = {
        'queryStringParameters': {
          'year': '2020'
        }
      }
      context = {}
      response = src.metrics.get_report(event, context)
      assert response['statusCode'] == 200
      assert mock_get_solved_metrics.assert_called_once_with('2020', None)
      assert mock_get_created_metrics.assert_called_once_with('2020', None)

def test_report_bad_year():
  event = {
    'queryStringParameters': {
      'year': '202'
    }
  }
  context = {}
  response = src.metrics.get_report(event, context)
  assert response['statusCode'] == 400
  assert response['body'] == 'Incorrect format of year: 202'

def test_report_bad_month():
  event = {
    'queryStringParameters': {
      'year': '2020',
      'month': '13'
    }
  }
  context = {}
  response = src.metrics.get_report(event, context)
  assert response['statusCode'] == 400
  assert response['body'] == 'Incorrect format of month: 13'
