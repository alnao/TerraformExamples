import logging
import json
import os
import azure.functions as func
from azure.storage.blob import BlobServiceClient
from urllib.parse import unquote


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Azure Function che lista i blob in un container.
    Può ricevere il path come query parameter.
    
    Esempio di utilizzo:
    - GET /api/list-blobs
    - GET /api/list-blobs?path=folder1
    - GET /api/list-blobs?path=folder1/subfolder
    """
    logging.info('Python HTTP trigger function processed a request.')

    try:
        # Ottieni configurazione dall'ambiente
        connection_string = os.environ.get('TEST_STORAGE_CONNECTION_STRING')
        container_name = os.environ.get('TEST_CONTAINER_NAME', 'testdata')
        
        if not connection_string:
            return func.HttpResponse(
                body=json.dumps({'error': 'TEST_STORAGE_CONNECTION_STRING not configured'}),
                mimetype='application/json',
                status_code=500
            )
        
        # Ottieni il path dal query parameter
        path = req.params.get('path', '')
        if path:
            path = unquote(path)
            if not path.endswith('/') and path != '':
                path += '/'
        
        logging.info(f'Listing blobs in container: {container_name}, path: {path}')
        
        # Crea blob service client
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        container_client = blob_service_client.get_container_client(container_name)
        
        # Lista blob con prefix
        blobs = []
        blob_list = container_client.list_blobs(name_starts_with=path)
        
        for blob in blob_list:
            blobs.append({
                'name': blob.name,
                'size': blob.size,
                'last_modified': blob.last_modified.isoformat() if blob.last_modified else None,
                'content_type': blob.content_settings.content_type if blob.content_settings else None,
                'blob_type': str(blob.blob_type) if blob.blob_type else 'BlockBlob'
            })
        
        # Prepara risposta
        result = {
            'container': container_name,
            'path': path,
            'count': len(blobs),
            'blobs': blobs
        }
        
        return func.HttpResponse(
            body=json.dumps(result, indent=2),
            mimetype='application/json',
            status_code=200
        )
        
    except Exception as e:
        logging.error(f'Error: {str(e)}')
        return func.HttpResponse(
            body=json.dumps({'error': str(e)}),
            mimetype='application/json',
            status_code=500
        )
