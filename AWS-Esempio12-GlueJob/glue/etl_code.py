import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark import SparkContext
from pyspark.sql.functions import col, length

sc = SparkContext.getOrCreate()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "BUCKET",
        "SOURCE_PATH",
        "SOURCE_FILE",
        "DEST_PATH",
        "numero_righe",
        "file_name",
    ],
)

job.init(args["JOB_NAME"], args)
logger = glue_context.get_logger()

bucket = args["BUCKET"]
source_path = args["SOURCE_PATH"]
dest_path = args["DEST_PATH"]

numero_righe = 0
file_name = "error"

try:
    numero_righe = int(args["numero_righe"])
    file_name = args["file_name"]
    logger.info("File: " + bucket + "//" + file_name)
except Exception:
    logger.info("errore recupero parametri")
    numero_righe = 0

logger.info(
    "Eseguo il numero_righe=" + str(numero_righe) + " nella file_name=" + str(file_name)
)

if numero_righe > 0:
    content = spark.read.options(header=True, delimiter=";").csv(
        "s3://" + bucket + "/" + file_name
    )

    normalized_columns = [c.lower().replace(" ", "_") for c in content.columns]
    content = content.toDF(*normalized_columns)

    content_filtered = (
        content.filter((length(col("nome")) > 0) & (col("cognome").isNotNull()))
        .filter("eta < 42")
        .filter(col("eta").cast("int") > 18)
    )

    logger.info("Scrivo il file " + bucket + "/" + file_name.replace(source_path, dest_path))
    content_filtered.select("*").toPandas().to_csv(
        "s3://" + bucket + "/" + file_name.replace(source_path, dest_path),
        index=False,
        header=True,
        sep=";",
    )
else:
    logger.info("Nessun file eseguito")
    job.commit()
    sys.exit(1)

logger.info("Fine con esito OK")
job.commit()
