# ==============================================================================
# EMBRC_publications_4_metrics.R
# Bibliographic Analysis - Step 4: OpenAlex Rich Authors, Citations & OpenAIRE OA
# ==============================================================================
# Copyright (C) 2026 Davide Di Cioccio & Ponytail
# Distributed under the terms of the GNU General Public License v3
# ==============================================================================

required_packages <- c("dplyr", "stringr", "readr", "httr", "jsonlite", "progress")
installed_packs <- required_packages %in% installed.packages()
if (any(!installed_packs)) {
  install.packages(required_packages[!installed_packs])
}
invisible(lapply(required_packages, require, character.only = TRUE))

get_current_script_name <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", cmd_args, value = TRUE)
  if (length(file_arg) > 0) {
    basename(sub("--file=", "", file_arg))
  } else if (!is.null(sys.frames()[[1]]$ofile)) {
    basename(sys.frames()[[1]]$ofile)
  } else {
    "EMBRC_publications_4_metrics.R"
  }
}

script_name <- get_current_script_name()
base_output_name <- sub("\\.[rR]$", ".csv", script_name)
base_dir <- file.path("D:", "coding", "EMBRC_publications", "cybergerac")
input_file <- file.path(base_dir, "output_csv", "EMBRC_publications_3_enricher_AI.csv")
output_file <- file.path(base_dir, "output_csv", base_output_name)

if (file.exists(output_file)) {
  tryCatch({
    test_con <- file(output_file, "r+")
    close(test_con)
  }, error = function(e) {
    stop("\n[WRITE LOCK ERROR] Output file is locked. Please close your CSV editor.\n\n")
  })
}

if (!file.exists(input_file)) {
  stop(sprintf("Input file not found: %s.", input_file))
}

cat(sprintf("\nRunning script: %s\n", script_name))
cat(sprintf("Reading data from: %s\n", input_file))
cat(sprintf("Writing metrics output to: %s\n\n", output_file))
flush.console()

master_data <- read_csv(input_file, show_col_types = FALSE)

validated_dois <- master_data %>%
  filter(validation_status %in% c("validated", "validated_ai")) %>%
  filter(!is.na(doi) & trimws(doi) != "") %>%
  distinct(doi) %>%
  pull(doi)

total_dois <- length(validated_dois)

if (total_dois == 0) {
  stop("No validated papers with a valid DOI found.")
}

fetch_openalex_rich_data <- function(doi) {
  clean_doi <- str_replace_all(str_trim(doi), "['\"]", "")
  clean_doi <- str_replace(clean_doi, "^https://doi.org/", "")
  
  url <- paste0("https://api.openalex.org/works/doi:", clean_doi, "?email=davide.dicioccio@embrc.eu")
  
  response <- tryCatch({
    GET(url, add_headers("User-Agent" = "EMBRC-Pipeline (mailto:davide.dicioccio@embrc.eu)"), timeout(5))
  }, error = function(e) {
    return(NULL)
  })
  
  default_res <- list(citations = 0, authors_rich = NA_character_, affiliation_rich = NA_character_)
  
  if (is.null(response) || status_code(response) != 200) {
    return(default_res)
  }
  
  raw_content <- content(response, as = "text", encoding = "UTF-8")
  parsed_data <- fromJSON(raw_content, simplifyVector = FALSE)
  
  # Fixed modulo arithmetic bug from core logic
  citations_count <- parsed_data$cited_by_count
  if (is.null(citations_count)) citations_count <- 0
  
  authorships <- parsed_data$authorships
  author_strings <- c()
  affiliation_strings <- c()
  
  if (!is.null(authorships) && length(authorships) > 0) {
    for (auth in authorships) {
      author_name <- auth$author$display_name %||% "Unknown"
      raw_orcid <- auth$author$orcid %||% ""
      clean_orcid <- str_extract(raw_orcid, "\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]")
      
      if (!is.na(clean_orcid) && clean_orcid != "") {
        author_strings <- c(author_strings, sprintf("%s (%s)", author_name, clean_orcid))
      } else {
        author_strings <- c(author_strings, author_name)
      }
      
      inst_list <- auth$institutions
      if (!is.null(inst_list) && length(inst_list) > 0) {
        for (inst in inst_list) {
          inst_name <- inst$display_name %||% "Unknown Institution"
          raw_ror <- inst$ror %||% ""
          clean_ror <- str_extract(raw_ror, "ror\\.org/[a-z0-9]+")
          country_iso <- inst$country_code %||% ""
          
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
        affiliation_strings <- c(affiliation_strings, "NA")
      }
    }
  }
  
  return(list(
    citations = as.integer(citations_count),
    authors_rich = ifelse(length(author_strings) > 0, paste(author_strings, collapse = "; "), NA_character_),
    affiliation_rich = ifelse(length(affiliation_strings) > 0, paste(unique(affiliation_strings), collapse = "; "), NA_character_)
  ))
}

normalize_oa_status <- function(raw_status) {
  if (is.null(raw_status)) return("unknown")
  clean_status <- str_to_lower(str_trim(as.character(raw_status)))
  result <- case_when(
    clean_status %in% c("c_abf2", "open") ~ "open",
    clean_status %in% c("c_14cb", "closed") ~ "closed",
    clean_status %in% c("c_16ec", "restricted") ~ "restricted",
    clean_status %in% c("c_f1cf", "embargo") ~ "embargo",
    TRUE ~ "unknown"
  )
  return(result)
}

resolve_best_oa_status <- function(status_vector) {
  if (is.null(status_vector) || length(status_vector) == 0) return("unknown")
  clean_statuses <- unique(unlist(lapply(status_vector, normalize_oa_status)))
  clean_statuses <- clean_statuses[!is.na(clean_statuses) & clean_statuses != "unknown"]
  if (length(clean_statuses) == 0) return("unknown")
  if ("open" %in% clean_statuses) return("open")
  if ("embargo" %in% clean_statuses) return("embargo")
  if ("restricted" %in% clean_statuses) return("restricted")
  return("closed")
}

fetch_openaire_oa_status <- function(doi) {
  clean_doi <- str_replace_all(str_trim(doi), "['\"]", "")
  clean_doi <- str_replace(clean_doi, "^https://doi.org/", "")
  url <- "https://api.openaire.eu/graph/v3/research-products"
  
  response <- tryCatch({
    GET(url, query = list(search = paste0('"', clean_doi, '"'), type = "publication", pageSize = 5), timeout = 5)
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(response) || status_code(response) != 200) return("unknown")
  
  raw_content <- content(response, as = "text", encoding = "UTF-8")
  parsed_json <- fromJSON(raw_content, simplifyVector = FALSE)
  if (is.null(parsed_json$results) || length(parsed_json$results) == 0) return("unknown")
  
  all_rights <- sapply(parsed_json$results, function(prod) prod$bestAccessRight %||% NA_character_)
  return(resolve_best_oa_status(unlist(all_rights)))
}

metrics_results <- list()
pb <- progress_bar$new(
  format = "  Fetching Metrics [:bar] :percent | DOI :current/:total | ETA: :eta",
  total = total_dois, clear = FALSE, width = 100
)

for (i in seq_along(validated_dois)) {
  current_doi <- validated_dois[i]
  alex_data <- fetch_openalex_rich_data(current_doi)
  oa_status <- fetch_openaire_oa_status(current_doi)
  
  metrics_results[[i]] <- data.frame(
    doi = current_doi,
    citations_count = alex_data$citations,
    openaire_oa_status = oa_status,
    authors_rich = alex_data$authors_rich,
    affiliation_rich = alex_data$affiliation_rich,
    stringsAsFactors = FALSE
  )
  pb$tick()
  Sys.sleep(0.35)
}

metrics_df <- bind_rows(metrics_results)

updated_master_data <- master_data %>%
  left_join(metrics_df, by = "doi", suffix = c("_old", "")) %>%
  mutate(
    citations_count = ifelse(!is.na(citations_count), citations_count, coalesce(citations_count_old, 0)),
    oa_status = ifelse(!is.na(openaire_oa_status), openaire_oa_status, coalesce(oa_status, "unknown")),
    authors = ifelse(!is.na(authors_rich), authors_rich, authors),
    affiliation = ifelse(!is.na(affiliation_rich), affiliation_rich, affiliation)
  ) %>%
  select(-ends_with("_old"), -any_of(c("openaire_oa_status", "authors_rich", "affiliation_rich")))

status_levels <- c("validated", "validated_ai", "review_required", "excluded")
final_dataset <- updated_master_data %>%
  mutate(validation_status = factor(validation_status, levels = status_levels, ordered = TRUE)) %>%
  arrange(validation_status, desc(year))

write_excel_csv(final_dataset, output_file)
cat(sprintf("\nStep 4 complete. Enriched data saved directly to %s\n", output_file))