# ==============================================================================
# EMBRC_publications_2_cleaner.R
# Bibliographic Analysis - Step 2: Database Standardisation and Tag Normalisation
# ==============================================================================
# Copyright (C) 2026 Davide Di Cioccio & Ponytail
# Distributed under the terms of the GNU General Public License v3
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. LOAD REQUIRED LIBRARIES AND DEPENDENCIES
# ------------------------------------------------------------------------------
required_packages <- c("dplyr", "stringr", "readr")
installed_packs <- required_packages %in% installed.packages()
if (any(!installed_packs)) {
  install.packages(required_packages[!installed_packs])
}
invisible(lapply(required_packages, require, character.only = TRUE))

# Dynamically set script-aligned output target inside output_csv folder
get_current_script_name <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", cmd_args, value = TRUE)
  if (length(file_arg) > 0) {
    basename(sub("--file=", "", file_arg))
  } else if (!is.null(sys.frames()[[1]]$ofile)) {
    basename(sys.frames()[[1]]$ofile)
  } else {
    "EMBRC_publications_2_cleaner.R"
  }
}

script_name <- get_current_script_name()
base_output_name <- sub("\\.[rR]$", ".csv", script_name)
base_dir <- file.path("D:", "coding", "EMBRC_publications", "cybergerac")
# Your AI-cleaned historical master dataset acts as the primary input
input_file <- file.path(base_dir, "output_csv", "EMBRC_publications_historical_master.csv")
output_file <- file.path(base_dir, "output_csv", base_output_name)

# ------------------------------------------------------------------------------
# 2. FILE EXISTENCE AND READ CHECK
# ------------------------------------------------------------------------------
if (!file.exists(input_file)) {
  stop(sprintf("Input file not found: %s. Please place your historical master CSV here.", input_file))
}

cat(sprintf("\nRunning script: %s\n", script_name))
cat(sprintf("Reading historical data from: %s\n", input_file))
cat(sprintf("Writing standardized output to: %s\n\n", output_file))
flush.console()

raw_data <- read_csv(input_file, show_col_types = FALSE)
total_rows <- nrow(raw_data)

# ------------------------------------------------------------------------------
# 3. TEXT SANITIZATION FUNCTIONS (HTML REMOVAL AND CLEANING)
# ------------------------------------------------------------------------------
strip_html_tags <- function(text_vector) {
  if (is.null(text_vector) || length(text_vector) == 0) return(NA_character_)
  text_vector <- gsub("<[^>]+>", " ", text_vector)
  text_vector <- gsub("&nbsp;", " ", text_vector)
  text_vector <- gsub("&amp;", "&", text_vector)
  text_vector <- gsub("&lt;", "<", text_vector)
  text_vector <- gsub("&gt;", ">", text_vector)
  text_vector <- str_squish(text_vector)
  return(text_vector)
}

clean_abstract_text <- function(text_vector) {
  if (is.null(text_vector) || length(text_vector) == 0) return(NA_character_)
  text_vector <- strip_html_tags(text_vector)
  text_vector <- gsub("^(?i)abstract([A-Z])", "\\1", text_vector)
  text_vector <- gsub("^(?i)background([A-Z])", "\\1", text_vector)
  text_vector <- gsub("^(?i)introduction([A-Z])", "\\1", text_vector)
  text_vector <- gsub("^(?i)abstract[:\\s-]*", "", text_vector)
  text_vector <- gsub("^(?i)background[:\\s-]*", "", text_vector)
  text_vector <- gsub("^(?i)introduction[:\\s-]*", "", text_vector)
  text_vector <- str_squish(text_vector)
  return(text_vector)
}

# ------------------------------------------------------------------------------
# 4. TAG STANDARDISATION AND FACTOR ORDERING
# ------------------------------------------------------------------------------
cat("Normalizing validation status tags and cleaning text fields...\n")
flush.console()

# Clean HTML characters in text columns
sanitized_data <- raw_data %>%
  mutate(
    title = strip_html_tags(title),
    abstract = clean_abstract_text(abstract)
  )

# Standardise status column by removing numerical prefixes and mapping to lowercase
standardized_data <- sanitized_data %>%
  mutate(
    validation_status = str_to_lower(str_trim(validation_status)),
    validation_status = case_when(
      str_detect(validation_status, "excluded") ~ "excluded",
      str_detect(validation_status, "validated_ai") ~ "validated_ai",
      str_detect(validation_status, "validated") ~ "validated",
      str_detect(validation_status, "review required") ~ "review_required",
      TRUE ~ "review_required" # Safe fallback for empty or unmapped rows
    )
  )

# Convert validation status into an ordered factor to push excluded records to the bottom
status_levels <- c("validated", "validated_ai", "review_required", "excluded")
standardized_data <- standardized_data %>%
  mutate(validation_status = factor(validation_status, levels = status_levels, ordered = TRUE)) %>%
  arrange(validation_status, desc(year))

# ------------------------------------------------------------------------------
# 5. EXPORT STANDARDISED DATABASE
# ------------------------------------------------------------------------------
write.csv(standardized_data, file = output_file, row.names = FALSE)

cat("\n========================================================================================================================\n")
cat("Standardisation completed successfully.\n")
print(table(standardized_data$validation_status, useNA = "always"))
cat(sprintf("\nSaved %d clean records directly to %s\n", nrow(standardized_data), output_file))