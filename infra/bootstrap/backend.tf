terraform {
  # Same bucket as the environments, distinct prefix. Created manually in
  # Phase 1 / Step 1.3 before this stack is ever applied.
  backend "gcs" {
    bucket = "dtp-ref-tfstate"
    prefix = "bootstrap"
  }
}
