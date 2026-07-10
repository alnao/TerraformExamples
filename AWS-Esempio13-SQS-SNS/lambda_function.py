import json
import boto3
import os
import time
import uuid

# Inizializzazione client AWS
dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')
sns = boto3.client('sns')

def lambda_handler(event, context):
    """
    Lambda function che riceve un messaggio in input e lo invia a:
    1. Una tabella DynamoDB (tracciamento log dell'invocazione)
    2. Una coda SQS
    3. Un topic SNS (notifica via email)
    """
    print("Invocazione Lambda con evento:", json.dumps(event))
    
    # 1. Estrazione del messaggio dall'input
    # Cerchiamo in diversi campi possibili per rendere la Lambda flessibile
    message_content = "Messaggio di default da Lambda"
    sender_name = "System"
    
    if isinstance(event, dict):
        if 'message' in event:
            message_content = event['message']
        elif 'body' in event:
            # Se invocato tramite API Gateway, il body potrebbe essere una stringa JSON
            try:
                body_data = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
                if isinstance(body_data, dict):
                    message_content = body_data.get('message', message_content)
                    sender_name = body_data.get('sender', sender_name)
            except Exception:
                message_content = event['body']
        
        if 'sender' in event:
            sender_name = event['sender']
            
    # Dettagli dell'invocazione
    request_id = context.aws_request_id if context else str(uuid.uuid4())
    timestamp = int(time.time())
    timestamp_str = time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(timestamp))
    
    # Inizializziamo il report delle operazioni
    status_report = {
        "dynamodb": "PENDING",
        "sqs": "PENDING",
        "sns": "PENDING"
    }
    
    errors = []

    # 2. Scrittura su DynamoDB
    table_name = os.environ.get('DYNAMODB_TABLE')
    if table_name:
        try:
            print(f"Salvataggio log su DynamoDB (tabella: {table_name})...")
            table = dynamodb.Table(table_name)
            table.put_item(
                Item={
                    'id': request_id,
                    'timestamp': timestamp,
                    'timestamp_utc': timestamp_str,
                    'message': message_content,
                    'sender': sender_name,
                    'status': 'PROCESSED'
                }
            )
            status_report["dynamodb"] = "SUCCESS"
            print("Salvataggio su DynamoDB completato con successo.")
        except Exception as e:
            status_report["dynamodb"] = f"FAILED: {str(e)}"
            errors.append(f"DynamoDB Error: {str(e)}")
            print(f"Errore durante la scrittura su DynamoDB: {str(e)}")
    else:
        status_report["dynamodb"] = "FAILED: Environment variable DYNAMODB_TABLE not set"
        errors.append("DynamoDB Table name not configured")

    # 3. Invio del messaggio alla coda SQS
    queue_url = os.environ.get('SQS_QUEUE_URL')
    if queue_url:
        try:
            print(f"Invio messaggio a SQS (coda: {queue_url})...")
            sqs_payload = {
                "message_id": request_id,
                "timestamp": timestamp_str,
                "sender": sender_name,
                "content": message_content
            }
            response = sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(sqs_payload),
                MessageAttributes={
                    'Sender': {
                        'DataType': 'String',
                        'StringValue': sender_name
                    }
                }
            )
            status_report["sqs"] = f"SUCCESS (MessageId: {response.get('MessageId')})"
            print(f"Messaggio inviato a SQS. MessageId: {response.get('MessageId')}")
        except Exception as e:
            status_report["sqs"] = f"FAILED: {str(e)}"
            errors.append(f"SQS Error: {str(e)}")
            print(f"Errore durante l'invio a SQS: {str(e)}")
    else:
        status_report["sqs"] = "FAILED: Environment variable SQS_QUEUE_URL not set"
        errors.append("SQS Queue URL not configured")

    # 4. Pubblicazione su SNS Topic (Notifica)
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if topic_arn:
        try:
            print(f"Invio notifica a SNS (Topic: {topic_arn})...")
            email_subject = f"Nuovo Messaggio da {sender_name} - AWS Lambda"
            email_body = (
                f"Ciao,\n\n"
                f"La Lambda function ha elaborato un nuovo messaggio.\n\n"
                f"Dettagli operazione:\n"
                f"- Request ID: {request_id}\n"
                f"- Timestamp UTC: {timestamp_str}\n"
                f"- Mittente: {sender_name}\n"
                f"- Messaggio: {message_content}\n\n"
                f"Stato elaborazione:\n"
                f"- Scrittura DynamoDB: {status_report['dynamodb']}\n"
                f"- Invio SQS: {status_report['sqs']}\n\n"
                f"Saluti,\n"
                f"AWS Lambda SQS-SNS Processor"
            )
            response = sns.publish(
                TopicArn=topic_arn,
                Subject=email_subject,
                Message=email_body,
                MessageAttributes={
                    'Sender': {
                        'DataType': 'String',
                        'StringValue': sender_name
                    }
                }
            )
            status_report["sns"] = f"SUCCESS (MessageId: {response.get('MessageId')})"
            print(f"Notifica inviata a SNS. MessageId: {response.get('MessageId')}")
        except Exception as e:
            status_report["sns"] = f"FAILED: {str(e)}"
            errors.append(f"SNS Error: {str(e)}")
            print(f"Errore durante l'invio a SNS: {str(e)}")
    else:
        status_report["sns"] = "FAILED: Environment variable SNS_TOPIC_ARN not set"
        errors.append("SNS Topic ARN not configured")

    # Risposta finale
    success = len(errors) == 0
    return {
        'statusCode': 200 if success else 207, # 207 Multi-Status in case of partial failures
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': {
            'success': success,
            'request_id': request_id,
            'timestamp': timestamp_str,
            'status_report': status_report,
            'errors': errors
        }
    }
