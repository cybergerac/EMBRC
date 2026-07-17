# ==============================================================================
# EMBRC_publications_1_retriever.R
# Bibliographic Analysis - Step 1: Rich Metadata Harvesting via OpenAlex
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
    "EMBRC_publications_1_retriever.R"
  }
}

script_name <- get_current_script_name()
base_output_name <- sub("\\.[rR]$", ".csv", script_name)
base_dir <- file.path("D:", "coding", "EMBRC_publications", "cybergerac")
output_file <- file.path(base_dir, "output_csv", base_output_name)

# Define search parameters
search_query <- "EMO-BON"
email_contact <- "davide.dicioccio@embrc.eu"

cat(sprintf("\nRunning script: %s\n", script_name))
cat(sprintf("Harvesting OpenAlex for query: '%s'\n", search_query))
cat(sprintf("Writing standardized output to: %s\n\n", output_file))
flush.console()

# ------------------------------------------------------------------------------
# 2. FETCH DATA FROM OPENALEX API
# ------------------------------------------------------------------------------
# Build API request URL with clean output mapping and contact details
encoded_query <- URLencode(search_query)
url <- sprintf("https://api.openalex.org/works?search=%s&mailto=%s&per_page=100", encoded_query, email_contact)

response <- tryCatch({
  GET(url, add_headers("User-Agent" = paste0("EMBRC-Pipeline (mailto:", email_contact, ")")), timeout(15))
}, error = function(e) {
  stop("Failed to connect to the OpenAlex API endpoint.")
})

if (status_code(response) != 200) {
  stop(sprintf("OpenAlex API returned error code: %d", status_code(response)))
}

raw_content <- content(response, as = "text", encoding = "UTF-8")
parsed_json <- fromJSON(raw_content, simplifyVector = FALSE)
works <- parsed_json$results
total_works <- length(works)

if (total_works == 0) {
  stop("No records returned for the specified search query.")
}

cat(sprintf("Found %d raw records. Parsing authors, ORCIDs, and ROR identifiers...\n", total_works))
flush.console()

# ------------------------------------------------------------------------------
# 3. PARSE RICH METADATA OBJECTS WITH PROGRESS BAR
# ------------------------------------------------------------------------------
parsed_records <- list()

pb <- progress_bar$new(
  format = "  Parsing OpenAlex records [:bar] :percent | Record :current/:total | ETA: :eta",
  total = total_works,
  clear = FALSE,
  width = 100
)

for (i in seq_along(works)) {
  work <- works[[i]]
  
  # Parse author list and attach ORCID identifiers in parentheses
  authorships <- work$authorships
  author_strings <- c()
  affiliation_strings <- c()
  
  if (!is.null(authorships) && length(authorships) > 0) {
    for (auth in authorships) {
      # Extract Author Name and ORCID
      author_name <- auth$author$display_name %||% "Unknown"
      raw_orcid <- auth$author$orcid %||% ""
      clean_orcid <- str_extract(raw_orcid, "\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]")
      
      if (!is.na(clean_orcid) && clean_orcid != "") {
        author_strings <- c(author_strings, sprintf("%s (%s)", author_name, clean_orcid))
      } else {
        author_strings <- c(author_strings, author_name)
      }
      
      # Extract Affiliation, ROR, and Country Code
      inst_list <- auth$institutions
      if (!is.null(inst_list) && length(inst_list) > 0) {
        for (inst in inst_list) {
          inst_name <- inst$display_name %||% "Unknown Institution"
          raw_ror <- inst$ror %||% ""
          clean_ror <- str_extract(raw_ror, "ror\\.org/[a-z0-9]+")
          country_iso <- inst$country_code %||% ""
          
          # Combine parameters into a structured, easily parsable affiliation token
          aff_token <- inst_name
          if (!is.na(clean_ror) && clean_ror != "") {
            aff_token <- sprintf("%s (https://%s)", aff_token, clean_ror)
          }
          if (country_iso != "") {
            aff_token <- sprintf("%s, %s", aff_token, toupper(country_iso))
          }
          affiliation_strings <- c(affiliation_strings, aff_token)
        }
      } else {
        # Keep empty token to preserve author alignment
        affiliation_strings <- c(affiliation_strings, "NA")
      }
    }
  }
  
  # Clean abstracts from OpenAlex inverted index
  clean_abstract <- NA_character_
  inv_index <- work$abstract_inverted_index
  if (!is.null(inv_index) && length(inv_index) > 0) {
    # Reconstruct abstract string from inverted index structure
    words_vector <- c()
    for (word in names(inv_index)) {
      positions <- unlist(inv_index[[word]])
      words_vector[positions + 1] <- word
    }
    clean_abstract <- str_squish(paste(na.omit(words_vector), collapse = " "))
  }
  
  # Collect attributes matching the master schema
  parsed_records[[i]] <- data.frame(
    title = work$title %||% "Untitled",
    year = as.integer(work$publication_year %||% NA_integer_),
    authors = paste(author_strings, collapse = "; "),
    doi = work$doi %||% NA_character_,
    url = work$id %||% NA_character_,
    source = "OpenAlex",
    query = search_query,
    abstract = clean_abstract,
    keywords = NA_character_,
    acknowledgements = NA_character_,
    affiliation = paste(unique(affiliation_strings), collapse = "; "),
    reference = "EMOBON",
    all_matching_references = "EMOBON",
    all_queries = search_query,
    validation_status = "review_required",
    author_count = as.integer(length(author_strings)),
    is_collaborative = ifelse(length(author_strings) > 1, "Yes", "No"),
    topic_ai = NA_character_,
    citations_count = as.integer(work$cited_by_count %||% 0),
    fwci = as.numeric(NA_real_),
    policy_citations_count = as.integer(0),
    is_oa = as.character(work$open_access$is_oa %||% "FALSE"),
    oa_status = as.character(work$open_access$oa_status %||% "unknown"),
    oa_pdf_url = work$open_access$oa_url %||% NA_character_,
    europe_pmc_grants = NA_character_,
    europe_pmc_db_links = NA_character_,
    wikidata_subject = NA_character_,
    stringsAsFactors = FALSE
  )
  
  pb$tick()
  flush.console()
  Sys.sleep(0.002)
}

# ------------------------------------------------------------------------------
# 4. CONSOLIDATE AND SAVE TO DISK
# ------------------------------------------------------------------------------
final_df <- bind_rows(parsed_records)

# Ensure all 27 canonical headers are present in the correct sequence
target_headers <- c(
  "title", "year", "authors", "doi", "url", "source", "query", "abstract", 
  "keywords", "acknowledgements", "affiliation", "reference", "all_matching_references", 
  "all_queries", "validation_status", "author_count", "is_collaborative", "topic_ai", 
  "citations_count", "fwci", "policy_citations_count", "is_oa", "oa_status", 
  "oa_pdf_url", "europe_pmc_grants", "europe_pmc_db_links", "wikidata_subject"
)

for (col_name in target_headers) {
  if (!col_name %in% names(final_df)) {
    final_df[[col_name]] <- NA
  }
}

final_df <- final_df %>% select(all_of(target_headers))

write.csv(final_df, output_file, row.names = FALSE)

cat("\n========================================================================================================================\n")
cat("Step 1 complete. Rich metadata parsed and standardized.\n")
cat(sprintf("Output file generated: %s\n", output_file))