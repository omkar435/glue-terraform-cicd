terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "omkar-tf-state-798283318175-ap-southeast-2"
    key          = "terraform-s3/dev/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# 1. Create S3 bucket
resource "aws_s3_bucket" "glue_bucket" {
  bucket = "omkar-glue-cicd-${data.aws_caller_identity.current.account_id}"
}

# 2. Create Glue IAM role
resource "aws_iam_role" "glue_role" {
  name = "omkar-glue-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "glue.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

# 3. Attach AWS Glue managed policy
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role = aws_iam_role.glue_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 4. Give Glue access to our S3 bucket
resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "glue-s3-access"

  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]

      Resource = [
        aws_s3_bucket.glue_bucket.arn,
        "${aws_s3_bucket.glue_bucket.arn}/*"
      ]
    }]
  })
}

# 5. Upload Glue Python script to S3
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.glue_bucket.id

  key = "scripts/glue_job.py"

  source = "${path.module}/glue_job.py"

  etag = filemd5("${path.module}/glue_job.py")
}

# 6. Create AWS Glue job
resource "aws_glue_job" "customer_etl" {
  name        = "omkar-customer-etl-job"
  description = "Customer CSV transformation job"

  role_arn = aws_iam_role.glue_role.arn

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_bucket.bucket}/scripts/glue_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"

    "--INPUT_PATH" = "s3://${aws_s3_bucket.glue_bucket.bucket}/input/"

    "--OUTPUT_PATH" = "s3://${aws_s3_bucket.glue_bucket.bucket}/output/"
  }

  depends_on = [
    aws_iam_role_policy_attachment.glue_service_policy,
    aws_iam_role_policy.glue_s3_policy,
    aws_s3_object.glue_script
  ]
}