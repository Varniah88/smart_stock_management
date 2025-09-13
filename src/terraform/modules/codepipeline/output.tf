# ==============================
# Outputs
# ==============================
output "pipeline_name" {
  value = aws_codepipeline.react_pipeline.name
}


output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}