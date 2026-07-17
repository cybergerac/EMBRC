# ==============================================================================
# EMBRC_publications_0_pipeline.R
# Bibliographic Analysis - Master Orchestrator Pipeline
# ==============================================================================
# Copyright (C) 2026 Davide Di Cioccio & Ponytail
# Distributed under the terms of the GNU General Public License v3
# ==============================================================================

clear_console <- function() {
  cat("\014")
}
clear_console()

message("========================================================================")
message("   LAUNCHING EMBRC GLOBAL BIBLIOGRAPHIC ANALYSIS PIPELINE (2018 - 2026) ")
message("========================================================================")

start_total_time <- Sys.time()

# Step 1: Data Retrieval via OpenAlex
if (file.exists("EMBRC_publications_1_retriever.R")) {
  message("\n>>> STEP 1: Harvesting OpenAlex Live API Registry...")
  source("EMBRC_publications_1_retriever.R")
} else {
  stop("Critical Error: EMBRC_publications_1_retriever.R missing.")
}

# Step 2: Text Sanitization & Validation Tag Normalization
if (file.exists("EMBRC_publications_2_cleaner.R")) {
  message("\n>>> STEP 2: Cleaning Text Fields and Normalizing Status Tags...")
  source("EMBRC_publications_2_cleaner.R")
} else {
  stop("Critical Error: EMBRC_publications_2_cleaner.R missing.")
}

# Step 3: AI Enrichment and Taxonomy Mapping via Gemini API
if (file.exists("EMBRC_publications_3_enricher_AI.R")) {
  message("\n>>> STEP 3: Executing Gemini AI Classification Pipeline...")
  source("EMBRC_publications_3_enricher_AI.R")
} else {
  stop("Critical Error: EMBRC_publications_3_enricher_AI.R missing.")
}

# Step 4: Citations Update and OpenAIRE Open Access Verification
if (file.exists("EMBRC_publications_4_metrics.R")) {
  message("\n>>> STEP 4: Fetching Rich Citation Metrics and OA Statuses...")
  source("EMBRC_publications_4_metrics.R")
} else {
  stop("Critical Error: EMBRC_publications_4_metrics.R missing.")
}

# Step 5: Relational Author-Institution Mapping & Excel Packing
if (file.exists("EMBRC_publications_5_authors_extractor.R")) {
  message("\n>>> STEP 5: Resolving ROR Registries and Generating Excel Workbooks...")
  source("EMBRC_publications_5_authors_extractor.R")
} else {
  stop("Critical Error: EMBRC_publications_5_authors_extractor.R missing.")
}

end_total_time <- Sys.time()
execution_duration <- round(difftime(end_total_time, start_total_time, units = "mins"), 2)

message("\n========================================================================")
message(" SUCCESS: Full Master Bibliographic Pipeline executed successfully!")
message(paste(" Total processing runtime duration:", execution_duration, "minutes."))
message("========================================================================")