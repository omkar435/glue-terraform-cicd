output "glue_job_name" {
  value = aws_glue_job.customer_etl.name
}

output "glue_bucket_name" {
  value = aws_s3_bucket.glue_bucket.bucket
}

output "glue_script_location" {
  value = aws_glue_job.customer_etl.command[0].script_location
}