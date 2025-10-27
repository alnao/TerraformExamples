# AWS Esempio 08 - API Gateway

API Gateway REST con due metodi:
- **GET /files**: Lista file da bucket S3
- **POST /calculate**: Calcola ipotenusa dati due cateti

## Risorse
- API Gateway REST API
- 2 Lambda Functions
- S3 Bucket
- IAM Roles e Policies
- CloudWatch Logs
- Usage Plan (opzionale)
- API Key (opzionale)
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio08ApiGateway/terraform.tfstate`.

## Utilizzo
```bash
terraform init
terraform apply

# Test GET
curl $(terraform output -raw get_files_url)

# Test POST
curl -X POST $(terraform output -raw post_calculate_url) \
  -H 'Content-Type: application/json' \
  -d '{"cateto_a":3,"cateto_b":4}'
```

## Esempio Response POST
```json
{
  "cateto_a": 3,
  "cateto_b": 4,
  "ipotenusa": 5.0,
  "formula": "sqrt(a² + b²)"
}
```

## Costi
- API Gateway: $3.50 per milione requests
- Lambda: $0.20 per milione + compute
- S3: Storage standard

## Riferimenti
- [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [API Gateway Pricing](https://aws.amazon.com/api-gateway/pricing/)
