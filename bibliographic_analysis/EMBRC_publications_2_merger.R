# ============================================================
# publications_merger.R
# Bibliographic Analysis - Step 2: Merge, Deduplication, and ESFRI Metrics
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

.packages = c("dplyr", "purrr", "stringr", "readr")
.inst <- .packages %in% installed.packages()
if(length(.packages[!.inst]) > 0) install.packages(.packages[!.inst])
lapply(.packages, require, character.only=TRUE)

input_dir <- "output_csv"

################################################################################
# 1. READ AND CONCATENATE ALL FILES FROM THE SUBFOLDER
################################################################################

message("Reading generated CSV files from output_csv/...")

files_to_load <- c(
  "EMOBON_papers.csv", "EMBRC_HQ_papers.csv", "EMBRC_nodes_papers.csv",
  "EMBRC_TA_projects.csv", "EMBRC_coordination.csv", "EMBRC_preparation.csv",
  "EMBRC_collaboration.csv"
)

loaded_dfs <- map(files_to_load, ~{
  file_path <- file.path(input_dir, .x)
  if (file.exists(file_path)) {
    df <- read_csv(file_path, show_col_types = FALSE)
    if (nrow(df) > 0) return(df)
  }
  return(NULL)
})

combined_raw <- bind_rows(compact(loaded_dfs))

if (nrow(combined_raw) == 0) {
  stop("No data found inside the output_csv folder. Ensure Step 1 has completed successfully.")
}

################################################################################
# 2. ADVANCED DEDUPLICATION AND REFERENCE AGGREGATION
################################################################################

message("Executing historical deduplication and reference mapping...")

# Create a clean lowercase title field to assist matching where DOIs are missing
combined_raw <- combined_raw %>%
  mutate(
    match_id = ifelse(!is.na(doi) & doi != "", str_to_lower(doi), str_to_lower(title)),
    match_id = str_squish(match_id)
  )

# Group by the match identifier to aggregate all source references into a single row
deduplicated_db <- combined_raw %>%
  group_by(match_id) %>%
  mutate(
    all_matching_references = paste(unique(reference), collapse = "; "),
    all_queries = paste(unique(query), collapse = "; "),
    # Fallback to keep non-NA values for essential metadata fields
    doi = first(na.omit(doi)),
    abstract = first(na.omit(abstract)),
    keywords = first(na.omit(keywords)),
    acknowledgements = first(na.omit(acknowledgements))
  ) %>%
  ungroup() %>%
  distinct(match_id, .keep_all = TRUE) %>%
  select(-match_id)

message(paste("Deduplication complete. Reduced dataset from", nrow(combined_raw), "to", nrow(deduplicated_db), "unique papers."))

################################################################################
# 3. COMPUTE ESFRI SCIEOMETRIC METRICS
################################################################################

message("Computing ESFRI metrics (Collaboration proxy and ordering)...")

deduplicated_db <- deduplicated_db %>%
  arrange(desc(year))

# International collaboration metric approximation based on author strings
# Counts commas or breaks as a proxy for team size and multi-institutional structures
deduplicated_db <- deduplicated_db %>%
  mutate(
    author_count = str_count(authors, ",") + 1,
    is_collaborative = ifelse(author_count > 2, "Yes", "No")
  )

################################################################################
# 4. SAVE INTERMEDIATE MERGED FILE FOR ALTMETRICS STEP
################################################################################

write.csv(deduplicated_db, "EMBRC_merged_publications.csv", row.names = FALSE)
message("Step 2 complete! Intermediate file generated: 'EMBRC_merged_publications.csv'.")