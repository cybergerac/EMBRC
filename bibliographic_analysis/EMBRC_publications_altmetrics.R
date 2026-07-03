# ============================================================
# publications_altmetrics.R
# Bibliographic Analysis - Step 3: Native Altmetrics Enrichment
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
# =============================================================

################################################################################
# LOAD LIBRARIES
################################################################################

.packages = c("dplyr", "purrr", "stringr", "readr", "httr", "jsonlite")
.inst <- .packages %in% installed.packages()
if(length(.packages[!.inst]) > 0) install.packages(.packages[!.inst])
lapply(.packages, require, character.only=TRUE)

input_file <- "EMBRC_merged_publications.csv"

################################################################################
# 1. LOAD MERGED DATA FROM STEP 2
################################################################################

if (!file.exists(input_file)) {
  stop("Error: EMBRC_merged_publications.csv not found. Ensure Step 2 has completed.")
}

message("Reading merged database from Step 2...")
merged_db <- read_csv(input_file, show_col_types = FALSE)

################################################################################
# 2. DEFINE NATIVE ALTMETRIC FETCH FUNCTION
################################################################################

message("Querying unique DOIs on Altmetric.com API...")

fetch_native_altmetric <- function(doi_string) {
  if (is.na(doi_string) || doi_string == "") {
    return(data.frame(altmetric_score = NA, policy_mentions = NA))
  }
  
  url <- paste0("https://api.altmetric.com/v1/doi/", URLencode(doi_string))
  
  res <- GET(url)
  Sys.sleep(0.5) # Dynamic respect to API throttling thresholds
  
  if (status_code(res) != 200) {
    return(data.frame(altmetric_score = NA, policy_mentions = NA))
  }
  
  data_parsed <- tryCatch({
    fromJSON(content(res, "text", encoding = "UTF-8"))
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(data_parsed)) {
    return(data.frame(altmetric_score = NA, policy_mentions = NA))
  }
  
  score <- if ("score" %in% names(data_parsed)) data_parsed$score else NA
  policy <- if ("cited_by_policies_count" %in% names(data_parsed)) data_parsed$cited_by_policies_count else NA
  
  return(data.frame(altmetric_score = score, policy_mentions = policy))
}

################################################################################
# 3. RUN FETCH AND BIND RESULTS
################################################################################

message("Fetching altmetric profiles (this might take a few minutes)...")
altmetric_results <- map_df(merged_db$doi, fetch_native_altmetric)

# Bind columns to create the final unified asset
final_enriched_db <- bind_cols(merged_db, altmetric_results)

################################################################################
# 4. SAVE FINAL ENRICHED DATA AS MASTER REPORT
################################################################################

write.csv(final_enriched_db, "EMBRC_master_enriched_publications.csv", row.names = FALSE)
message("Step 3 complete! Final master file generated: 'EMBRC_master_enriched_publications.csv'.")