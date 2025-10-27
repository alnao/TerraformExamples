# AWS Esempio 07 - Step Functions

Step Function che copia file da bucket A a B e invoca Lambda per logging.

## Risorse
- 2 S3 Buckets (source/destination)
- Step Function State Machine
- Lambda Logger Function
- EventBridge Rule e Target
- IAM Roles e Policies
- CloudWatch Logs
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio07StepFunction/terraform.tfstate`.

## Workflow
1. File caricato in bucket A
2. EventBridge trigger Step Function
3. Step Function copia file in bucket B
4. Step Function invoca Lambda per log
5. Lambda scrive log con print

## Utilizzo
```bash
terraform init
terraform apply
aws s3 cp test.txt s3://aws-esempio07-step-source/test.txt
aws logs tail /aws/lambda/step-function-logger --follow
```

## Riferimenti
- [Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Step Functions Pricing](https://aws.amazon.com/step-functions/pricing/)
