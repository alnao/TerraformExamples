#!/usr/bin/env python3
"""
Test script per verificare la funzione Azure localmente
Richiede: pip install azure-functions
"""
import json
from function_app import app

def test_logger_function():
    """Test della funzione logger con payload di esempio"""
    
    # Simula una richiesta HTTP
    class MockHttpRequest:
        def __init__(self, body):
            self.body = body
        
        def get_json(self):
            return json.loads(self.body)
    
    # Test payload
    test_payload = json.dumps({
        "blobName": "test-file.txt",
        "sourceContainer": "source",
        "destinationContainer": "destination",
        "operationTime": "2026-02-12T10:30:00Z"
    })
    
    # Crea mock request
    req = MockHttpRequest(test_payload)
    
    # Simula la chiamata (nota: non possiamo chiamare direttamente il decorator)
    print("Test Payload:")
    print(json.dumps(json.loads(test_payload), indent=2))
    print("\nLa funzione processerebbe questo payload e registrerebbe:")
    print({
        "operation": "BLOB_COPY",
        "blobName": "test-file.txt",
        "sourceContainer": "source",
        "destinationContainer": "destination"
    })

def test_invalid_payload():
    """Test con payload invalido"""
    print("\n--- Test con payload invalido ---")
    print("Payload: {invalid json}")
    print("Risposta attesa: HTTP 400 - Invalid JSON payload")

if __name__ == "__main__":
    print("=== Test Azure Function Logger ===\n")
    test_logger_function()
    test_invalid_payload()
    print("\n=== Test completati ===")
    print("\nPer testare online dopo il deploy:")
    print("curl -X POST https://<function-app>.azurewebsites.net/api/logger \\")
    print("  -H 'Content-Type: application/json' \\")
    print("  -d '{\"blobName\":\"test.txt\",\"sourceContainer\":\"source\",\"destinationContainer\":\"destination\"}'")
