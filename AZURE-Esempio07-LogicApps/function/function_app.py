import azure.functions as func
import logging
import json
from datetime import datetime

app = func.FunctionApp()

@app.route(route="logger", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def logger(req: func.HttpRequest) -> func.HttpResponse:
    """
    Function per logging delle operazioni di copia blob
    Riceve informazioni sul blob copiato e registra l'operazione
    """
    logging.info('Function logger invocata')

    try:
        req_body = req.get_json()
        
        blob_name = req_body.get('blobName')
        source_container = req_body.get('sourceContainer')
        destination_container = req_body.get('destinationContainer')
        operation_time = req_body.get('operationTime', datetime.utcnow().isoformat())
        
        log_message = {
            "timestamp": datetime.utcnow().isoformat(),
            "operation": "BLOB_COPY",
            "blobName": blob_name,
            "sourceContainer": source_container,
            "destinationContainer": destination_container,
            "operationTime": operation_time,
            "status": "SUCCESS"
        }
        
        logging.info(f"Blob copy operation logged: {json.dumps(log_message)}")
        
        return func.HttpResponse(
            json.dumps({
                "message": "Operation logged successfully",
                "details": log_message
            }),
            status_code=200,
            mimetype="application/json"
        )
        
    except ValueError as ve:
        logging.error(f"Invalid JSON payload: {str(ve)}")
        return func.HttpResponse(
            json.dumps({"error": "Invalid JSON payload"}),
            status_code=400,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Error processing request: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="health", methods=["GET"], auth_level=func.AuthLevel.ANONYMOUS)
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """Health check endpoint"""
    return func.HttpResponse(
        json.dumps({"status": "healthy", "timestamp": datetime.utcnow().isoformat()}),
        status_code=200,
        mimetype="application/json"
    )
