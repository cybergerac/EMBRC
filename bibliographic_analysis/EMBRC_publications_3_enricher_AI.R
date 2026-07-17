# ==============================================================================
# EMBRC_publications_3_enricher_AI.R
# Bibliographic Analysis - Step 3: AI Classification and Topic Mapping
# ==============================================================================
# Copyright (C) 2026 Davide Di Cioccio & Ponytail
# Distributed under the terms of the GNU General Public License v3
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. LOAD REQUIRED LIBRARIES AND DEPENDENCIES
# ------------------------------------------------------------------------------
required_packages <- c("dplyr", "stringr", "readr", "httr", "jsonlite", "progress")
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
    "EMBRC_publications_3_enricher_AI.R"
  }
}

script_name <- get_current_script_name()
base_output_name <- sub("\\.[rR]$", ".csv", script_name)
base_dir <- file.path("D:", "coding", "EMBRC_publications", "cybergerac")
input_file <- file.path(base_dir, "output_csv", "EMBRC_publications_2_cleaner.csv")
output_file <- file.path(base_dir, "output_csv", base_output_name)

# Retrieve Gemini API Key from system environment
gemini_key <- Sys.getenv("GEMINI_API_KEY")
if (gemini_key == "") {
  gemini_key <- "YOUR_GEMINI_API_KEY_HERE" 
}

# ------------------------------------------------------------------------------
# 2. FILE EXISTENCE AND READ CHECK
# ------------------------------------------------------------------------------
if (!file.exists(input_file)) {
  stop(sprintf("Input file not found: %s. Please run Step 2 first.", input_file))
}

cat(sprintf("\nRunning script: %s\n", script_name))
cat(sprintf("Reading standardized data from: %s\n", input_file))
cat(sprintf("Writing enriched output to: %s\n\n", output_file))
flush.console()

master_data <- read_csv(input_file, show_col_types = FALSE)
total_rows <- nrow(master_data)

# Ensure required columns exist
required_cols <- c("title", "abstract", "validation_status", "doi")
missing_cols <- setdiff(required_cols, names(master_data))
if (length(missing_cols) > 0) {
  stop(sprintf("Missing required columns in input file: %s", paste(missing_cols, collapse = ", ")))
}

# Initialize target columns if they do not exist in the source file
if (!"topic_ai" %in% names(master_data)) {
  master_data$topic_ai <- NA_character_
}

# Identify rows that need Gemini processing (review needed OR validated but missing topics)
target_indices <- which(
  master_data$validation_status == "review_required" | 
    (master_data$validation_status %in% c("validated", "validated_ai") & 
       (is.na(master_data$topic_ai) | trimws(master_data$topic_ai) == ""))
)
total_targets <- length(target_indices)

cat(sprintf("Found %d papers requiring active AI classification or topic mapping out of %d total records.\n", total_targets, total_rows))
flush.console()

# ------------------------------------------------------------------------------
# 3. GEMINI API INTERACTION FUNCTION
# ------------------------------------------------------------------------------
classify_paper_with_gemini <- function(title, abstract, api_key) {
  if (api_key == "YOUR_GEMINI_API_KEY_HERE" || api_key == "") {
    return(list(validation = "review_required", topics = ""))
  }
  
  url <- "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
  
  taxonomy_list <- paste(c(
    "Anti-cancer drugs", "Antimicrobials", "Bioremediation and ecotoxicity", "Climate change", 
    "Cosmetics", "Data Management", "Ecology", "Evolution", "Finfish aquaculture", "Fisheries", 
    "Habitat restoration", "Marine Protected Areas", "Marine biotechnology", "Nutraceuticals", 
    "Plankton studies", "Renewable energy", "Science policy", "Seaweed aquaculture", 
    "Shellfish aquaculture", "Systematics and Taxonomy"
  ), collapse = ", ")
  
  prompt_text <- sprintf(
    "You are an expert marine biology data classifier. Analyze the following paper title and abstract.
    
    Title: %s
    Abstract: %s
    
    Task 1: Decide if this paper has any scientific connection with marine biology, marine organisms, oceanography, marine ecosystems, or related technologies.
    Set your decision as 'validated_ai' if it connects, or 'excluded' if it does not.
    
    Task 2: If and only if you validated the paper, select up to 3 scientific topics from this list: [%s].
    If a topic is difficult to resolve or borderline, place it in parentheses, e.g., '(Ecology)'. If the paper is excluded, leave topics empty.
    
    Return ONLY a valid JSON object matching this structure:
    {
      \"validation\": \"validated_ai\" or \"excluded\",
      \"topics\": \"Topic 1; Topic 2\"
    }",
    title, abstract, taxonomy_list
  )
  
  body_data <- list(
    contents = list(
      parts = list(
        list(text = prompt_text)
      )
    ),
    generationConfig = list(
      responseMimeType = "application/json"
    )
  )
  
  response <- tryCatch({
    POST(
      url = paste0(url, "?key=", api_key),
      body = body_data,
      encode = "json",
      timeout(10)
    )
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(response) || status_code(response) != 200) {
    return(list(validation = "review_required", topics = ""))
  }
  
  raw_content <- content(response, as = "text", encoding = "UTF-8")
  parsed_response <- fromJSON(raw_content, simplifyVector = FALSE)
  
  candidate_json <- parsed_response$candidates[[1]]$content$parts[[1]]$text
  clean_data <- tryCatch({
    fromJSON(candidate_json)
  }, error = function(e) {
    return(list(validation = "review_required", topics = ""))
  })
  
  return(list(
    validation = coalesce(clean_data$validation, "review_required"),
    topics = coalesce(clean_data$topics, "")
  ))
}

# ------------------------------------------------------------------------------
# 4. EXECUTION PIPELINE WITH DYNAMIC PROGRESS BAR AND ETA
# ------------------------------------------------------------------------------
if (total_targets > 0) {
  cat("\nProcessing AI classification and topic assignment for required rows...\n")
  pb <- progress_bar$new(
    format = "  Classifying with Gemini AI [:bar] :percent | Paper :current/:total | ETA: :eta",
    total = total_targets,
    clear = FALSE,
    width = 100
  )
  
  for (idx in target_indices) {
    title <- master_data$title[idx]
    abstract <- master_data$abstract[idx]
    original_status <- master_data$validation_status[idx]
    
    ai_result <- classify_paper_with_gemini(title, abstract, gemini_key)
    
    # If the paper was already validated, prevent demotion by Gemini
    if (original_status %in% c("validated", "validated_ai")) {
      master_data$topic_ai[idx] <- ai_result$topics
    } else {
      master_data$validation_status[idx] <- ai_result$validation
      master_data$topic_ai[idx] <- ai_result$topics
    }
    
    Sys.sleep(0.4)
    pb$tick()
  }
}

cat("\n")

# ------------------------------------------------------------------------------
# 5. CONSOLIDATE AND WRITE TO DISK
# ------------------------------------------------------------------------------
status_levels <- c("validated", "validated_ai", "review_required", "excluded")
final_output_df <- master_data %>%
  mutate(validation_status = factor(validation_status, levels = status_levels, ordered = TRUE)) %>%
  arrange(validation_status, desc(year))

write.csv(final_output_df, output_file, row.names = FALSE)

cat("========================================================================================================================\n")
cat("Step 3 complete. AI classification and topic mapping executed successfully.\n")
print(table(final_output_df$validation_status, useNA = "always"))
cat(sprintf("\nSaved enriched database directly to %s\n", output_file))