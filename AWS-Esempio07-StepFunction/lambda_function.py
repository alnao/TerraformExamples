import json
from datetime import datetime

def lambda_handler(event, context):
    """Lambda che scrive log con print per Step Function"""
    
    action = event.get('action', 'unknown')
    timestamp = datetime.now().isoformat()
    
    print(f"[{timestamp}] Step Function Log Event")
    print(f"Action: {action}")
    
    if action == 'copy_completed':
        print(f"✓ File copied successfully")
        print(f"  Source: s3://{event.get('sourceBucket')}/{event.get('objectKey')}")
        print(f"  Destination: s3://{event.get('destinationBucket')}/{event.get('objectKey')}")
        print(f"  Copy Result: {json.dumps(event.get('copyResult', {}))}")
        
    elif action == 'copy_failed':
        print(f"✗ File copy failed")
        print(f"  Source: s3://{event.get('sourceBucket')}/{event.get('objectKey')}")
        print(f"  Error: {json.dumps(event.get('error', {}))}")
        
    elif action == 'lambda_failed':
        print(f"✗ Lambda invocation failed")
        print(f"  Error: {json.dumps(event.get('error', {}))}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Log written for action: {action}',
            'timestamp': timestamp
        })
    }
