# ====================================
# IAM - RUOLO CONDIVISO DALLE TRE LAMBDA
# ====================================

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "s3-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.docs.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.docs.arn
      }
    ]
  })
}

# Textract legge l'immagine da S3 usando le credenziali della Lambda che lo
# invoca: bastano quindi i permessi S3 gia' concessi sopra.
# DetectDocumentText e AnalyzeDocument non supportano permessi a livello di
# risorsa, l'unico valore ammesso per Resource e' "*".
resource "aws_iam_role_policy" "lambda_textract" {
  name = "textract-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Detect*/Analyze* sincrone per le immagini,
        # Start*/Get* asincrone per i PDF multipagina
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument",
          "textract:StartDocumentTextDetection",
          "textract:StartDocumentAnalysis",
          "textract:GetDocumentTextDetection",
          "textract:GetDocumentAnalysis"
        ]
        Resource = "*"
      },
      {
        # Per avviare un job asincrono la Lambda passa a Textract il ruolo
        # che gli serve per pubblicare su SNS: senza PassRole la Start*
        # fallisce con AccessDeniedException.
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.textract_sns.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "textract.amazonaws.com"
          }
        }
      }
    ]
  })
}
