import sys

from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import upper, col

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "INPUT_PATH", "OUTPUT_PATH"]
)

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Read CSV from S3
df = spark.read.option("header", "true").csv(args["INPUT_PATH"])

# Transform customer names
transformed_df = df.withColumn(
    "customer_name",
    upper(col("customer_name"))
)

# Write output to S3
transformed_df.write \
    .mode("overwrite") \
    .option("header", "true") \
    .csv(args["OUTPUT_PATH"])

print("Glue ETL job completed successfully")