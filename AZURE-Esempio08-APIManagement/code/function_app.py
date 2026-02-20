import logging
import json
import os
import math
import azure.functions as func
from azure.storage.blob import BlobServiceClient
from urllib.parse import unquote

# Crea l'app Azure Functions (Python v2 model)
app = func.FunctionApp()


@app.function_name(name="list_blobs")
@app.route(route="list-blobs", auth_level=func.AuthLevel.FUNCTION, methods=["GET"])
def list_blobs(req: func.HttpRequest) -> func.HttpResponse:
    """
    Azure Function che lista i blob in un container dello Storage Account.

    Query parameters:
    - path: (opzionale) prefisso per filtrare i blob

    Esempio di utilizzo:
    - GET /api/list-blobs
    - GET /api/list-blobs?path=folder1
    - GET /api/list-blobs?path=folder1/subfolder
    """
    logging.info("list_blobs - HTTP trigger function processed a request.")

    try:
        # Ottieni configurazione dall'ambiente
        connection_string = os.environ.get("FILES_STORAGE_CONNECTION")
        container_name = os.environ.get("FILES_CONTAINER_NAME", "files")

        if not connection_string:
            return func.HttpResponse(
                body=json.dumps({"error": "FILES_STORAGE_CONNECTION not configured"}),
                mimetype="application/json",
                status_code=500,
            )

        # Ottieni il path dal query parameter
        path = req.params.get("path", "")
        if path:
            path = unquote(path)
            if not path.endswith("/") and path != "":
                path += "/"

        logging.info(f"Listing blobs in container: {container_name}, path: {path}")

        # Crea blob service client
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        container_client = blob_service_client.get_container_client(container_name)

        # Lista blob con prefix
        blobs = []
        blob_list = container_client.list_blobs(name_starts_with=path if path else None)

        for blob in blob_list:
            blobs.append(
                {
                    "name": blob.name,
                    "size": blob.size,
                    "last_modified": (
                        blob.last_modified.isoformat() if blob.last_modified else None
                    ),
                    "content_type": (
                        blob.content_settings.content_type
                        if blob.content_settings
                        else None
                    ),
                    "blob_type": (
                        str(blob.blob_type) if blob.blob_type else "BlockBlob"
                    ),
                }
            )

        # Prepara risposta
        result = {
            "container": container_name,
            "path": path,
            "count": len(blobs),
            "blobs": blobs,
        }

        return func.HttpResponse(
            body=json.dumps(result, indent=2),
            mimetype="application/json",
            status_code=200,
        )

    except Exception as e:
        logging.error(f"Error listing blobs: {str(e)}")
        return func.HttpResponse(
            body=json.dumps({"error": str(e)}),
            mimetype="application/json",
            status_code=500,
        )


@app.function_name(name="calculate_hypotenuse")
@app.route(route="calculate-hypotenuse", auth_level=func.AuthLevel.FUNCTION, methods=["POST"])
def calculate_hypotenuse(req: func.HttpRequest) -> func.HttpResponse:
    """
    Azure Function che calcola l'ipotenusa dati due cateti.

    Request body (JSON):
    {
        "cateto_a": <numero>,
        "cateto_b": <numero>
    }

    Response (JSON):
    {
        "cateto_a": <numero>,
        "cateto_b": <numero>,
        "ipotenusa": <numero>
    }
    """
    logging.info("calculate_hypotenuse - HTTP trigger function processed a request.")

    try:
        # Parse del body JSON
        try:
            req_body = req.get_json()
        except ValueError:
            return func.HttpResponse(
                body=json.dumps(
                    {
                        "error": "Invalid JSON body. Expected: {\"cateto_a\": <number>, \"cateto_b\": <number>}"
                    }
                ),
                mimetype="application/json",
                status_code=400,
            )

        # Validazione parametri
        cateto_a = req_body.get("cateto_a")
        cateto_b = req_body.get("cateto_b")

        if cateto_a is None or cateto_b is None:
            return func.HttpResponse(
                body=json.dumps(
                    {
                        "error": "Missing required fields: cateto_a and cateto_b",
                        "example": {"cateto_a": 3, "cateto_b": 4},
                    }
                ),
                mimetype="application/json",
                status_code=400,
            )

        # Converti a numeri
        try:
            cateto_a = float(cateto_a)
            cateto_b = float(cateto_b)
        except (TypeError, ValueError):
            return func.HttpResponse(
                body=json.dumps(
                    {"error": "cateto_a and cateto_b must be valid numbers"}
                ),
                mimetype="application/json",
                status_code=400,
            )

        # Validazione valori positivi
        if cateto_a <= 0 or cateto_b <= 0:
            return func.HttpResponse(
                body=json.dumps(
                    {"error": "cateto_a and cateto_b must be positive numbers"}
                ),
                mimetype="application/json",
                status_code=400,
            )

        # Calcolo ipotenusa: c = sqrt(a^2 + b^2)
        ipotenusa = math.sqrt(cateto_a**2 + cateto_b**2)

        result = {
            "cateto_a": cateto_a,
            "cateto_b": cateto_b,
            "ipotenusa": round(ipotenusa, 6),
            "formula": "sqrt(cateto_a² + cateto_b²)",
        }

        logging.info(f"Calculated hypotenuse: {cateto_a}² + {cateto_b}² = {ipotenusa}²")

        return func.HttpResponse(
            body=json.dumps(result, indent=2),
            mimetype="application/json",
            status_code=200,
        )

    except Exception as e:
        logging.error(f"Error calculating hypotenuse: {str(e)}")
        return func.HttpResponse(
            body=json.dumps({"error": str(e)}),
            mimetype="application/json",
            status_code=500,
        )
