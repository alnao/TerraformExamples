import json
import math

def lambda_handler(event, context):
    """
    Lambda function per calcolare l'ipotenusa di un triangolo rettangolo.
    Invocata da API Gateway POST /calculate
    Formula: ipotenusa = sqrt(a² + b²)
    """
    try:
        # Parse body from API Gateway event
        body = json.loads(event.get('body', '{}'))
        
        # Extract cateti from request
        cateto_a = float(body.get('cateto_a', 0))
        cateto_b = float(body.get('cateto_b', 0))
        
        # Validation
        if cateto_a <= 0 or cateto_b <= 0:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'error': 'Invalid input',
                    'message': 'I cateti devono essere numeri positivi maggiori di zero'
                })
            }
        
        # Calculate hypotenuse using Pythagorean theorem
        ipotenusa = math.sqrt(cateto_a**2 + cateto_b**2)
        
        # Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'cateto_a': cateto_a,
                'cateto_b': cateto_b,
                'ipotenusa': round(ipotenusa, 2),
                'formula': 'sqrt(a² + b²)',
                'perimeter': round(cateto_a + cateto_b + ipotenusa, 2),
                'area': round((cateto_a * cateto_b) / 2, 2)
            })
        }
    except ValueError as ve:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'Invalid input',
                'message': 'I cateti devono essere numeri validi'
            })
        }
    except Exception as e:
        print(f"Error calculating hypotenuse: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e),
                'message': 'Internal server error during calculation'
            })
        }
