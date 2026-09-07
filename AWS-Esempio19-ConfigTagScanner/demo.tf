# ====================================
# RISORSE DI PROVA
#
# Due bucket identici tranne che per i tag: servono a vedere subito la regola
# che ne marca uno COMPLIANT e l'altro NON_COMPLIANT.
# Si disattivano con create_demo_resources = false.
# ====================================

resource "aws_s3_bucket" "demo_ok" {
  count = var.create_demo_resources ? 1 : 0

  bucket        = "${var.project_name}-demo-ok-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy

  # Tutti i tag richiesti: questo bucket risultera' COMPLIANT
  tags = local.common_tags
}

resource "aws_s3_bucket" "demo_ko" {
  count = var.create_demo_resources ? 1 : 0

  bucket        = "${var.project_name}-demo-ko-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy

  # Mancano cost, createdWith e createdBy: questo bucket risultera' NON_COMPLIANT
  tags = {
    project     = "esempio19"
    environment = "dev"
  }
}
