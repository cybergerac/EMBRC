# ==============================================================================
# EMBRC_publications_analysis_pipeline.R
# EMBRC Bibliographic Pipeline Orchestrator (3-Step Modular Sequence)
# 
# ==============================================================================
# This tool is an evolution and adaptation of the original code developed by 
# Christina Pavloudi, rewritten to support institutional classification and Altmetrics enrichment.
# source file: https://github.com/cpavloud/retrieve_publications/blob/main/Retrieve_publications.R
# ==============================================================================
# 
# Davide Di Cioccio
# davide.dicioccio@embrc.eu
# https://www.embrc.eu
# ==============================================================================

message("==========================================================================")
message("LAUNCHING EMBRC 3-STEP BIBLIOGRAPHIC PIPELINE")
message("==========================================================================")

# ------------------------------------------------------------------------------
# STEP 1: FETCH RAW DATA FROM WEB APIS
# ------------------------------------------------------------------------------
if (file.exists("publications_retriever.R")) {
  message("\n>>> STEP 1: Launching publications_retriever (Web API Fetch)...")
  source("publications_retriever.R")
} else {
  stop("Critical Error: publications_retriever.R not found in the directory.")
}

# ------------------------------------------------------------------------------
# STEP 2: MERGE AND DEDUPLICATE CHUNKS
# ------------------------------------------------------------------------------
if (file.exists("publications_merger.R")) {
  message("\n>>> STEP 2: Launching publications_merger (Deduplication & ESFRI Metrics)...")
  source("publications_merger.R")
} else {
  stop("Critical Error: publications_merger.R not found in the directory.")
}

# ------------------------------------------------------------------------------
# STEP 3: ENRICH WITH NATIVE ALTMETRICS
# ------------------------------------------------------------------------------
if (file.exists("publications_altmetrics.R")) {
  message("\n>>> STEP 3: Launching publications_altmetrics (Native Altmetric.com API Query)...")
  source("publications_altmetrics.R")
} else {
  stop("Critical Error: publications_altmetrics.R not found in the directory.")
}

message("\n==========================================================================")
message("SUCCESS: Full 3-step pipeline executed flawlessly!")
message("Your final enriched institutional database is ready.")
message("==========================================================================")
