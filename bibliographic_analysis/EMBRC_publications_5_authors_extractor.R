# ==============================================================================
# EMBRC_publications_5_authors_extractor.R
# Bibliographic Analysis - Step 5: Relational Excel Export (Papers & Authors)
# ==============================================================================
# Copyright (C) 2026 Davide Di Cioccio & Ponytail
# Distributed under the terms of the GNU General Public License v3
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. LOAD REQUIRED LIBRARIES AND DEPENDENCIES
# ------------------------------------------------------------------------------
required_packages <- c("dplyr", "stringr", "readr", "purrr", "httr", "jsonlite", "progress", "writexl", "countrycode")
installed_packs <- required_packages %in% installed.packages()
if (any(!installed_packs)) {
  install.packages(required_packages[!installed_packs])
}
invisible(lapply(required_packages, require, character.only = TRUE))

# Use relative paths to ensure absolute portability between local setups and Dropbox
input_file <- file.path("output_csv", "EMBRC_publications_4_metrics.csv")
output_file <- file.path("output_csv", "EMBRC_KPI_scientific_excellence.xlsx")

# ------------------------------------------------------------------------------
# 2. PRE-EMPTIVE WRITE LOCK CHECK
# ------------------------------------------------------------------------------
if (file.exists(output_file)) {
  tryCatch({
    test_con <- file(output_file, "r+")
    close(test_con)
  }, error = function(e) {
    stop("\n[WRITE LOCK ERROR] Output Excel workbook is currently open. Please close it.\n\n")
  })
}

# ------------------------------------------------------------------------------
# 3. INPUT FILE VALIDITY AND DISK CHECKS
# ------------------------------------------------------------------------------
if (!file.exists(input_file)) {
  stop(sprintf("Input file not found: %s. Run Step 4 first.", input_file))
}

cat(sprintf("Reading data from relative path: %s\n", input_file))
cat(sprintf("Writing Excel workbook to relative path: %s\n\n", output_file))
flush.console()

master_data <- read_csv(input_file, show_col_types = FALSE)
validated_data <- master_data %>% filter(validation_status %in% c("validated", "validated_ai"))
total_papers <- nrow(validated_data)

if (total_papers == 0) {
  stop("No validated records available to process.")
}

# ------------------------------------------------------------------------------
# 4. EXTRACTION AND PARSING LOOP
# ------------------------------------------------------------------------------
extracted_rows <- list()
for (i in 1:total_papers) {
  row_data <- validated_data[i, ]
  author_list <- if (!is.na(row_data$authors)) str_trim(str_split(row_data$authors, ";")[[1]]) else character(0)
  author_list <- author_list[author_list != ""]
  affiliation_list <- if (!is.na(row_data$affiliation)) str_trim(str_split(row_data$affiliation, ";")[[1]]) else character(0)
  
  if (length(author_list) > 0) {
    for (j in seq_along(author_list)) {
      current_author <- author_list[j]
      current_aff <- if (j <= length(affiliation_list)) affiliation_list[j] else coalesce(affiliation_list[1], NA_character_)
      
      orcid_match <- str_extract(current_author, "\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]")
      ror_match <- str_extract(current_aff, "ror\\.org/[a-z0-9]+")
      
      clean_inst_name <- if (!is.na(current_aff)) {
        temp_name <- str_remove(current_aff, "\\s*\\(https?://ror\\.org/[a-z0-9]+\\)")
        str_trim(str_remove(temp_name, ",\\s*[A-Z]{2}$"))
      } else {
        NA_character_
      }
      
      extracted_rows[[length(extracted_rows) + 1]] <- data.frame(
        doi = row_data$doi, title = row_data$title, year = row_data$year,
        author_name = str_trim(str_remove(current_author, "\\s*\\(.*\\)")),
        author_orcid = ifelse(is.na(orcid_match), NA_character_, orcid_match),
        institution_name = clean_inst_name,
        institution_ror = ifelse(is.na(ror_match), NA_character_, ror_match),
        country_code = ifelse(is.na(str_extract(current_aff, "[A-Z]{2}$")), NA_character_, str_extract(current_aff, "[A-Z]{2}$")),
        country_name = NA_character_, institution_type = NA_character_, continent_name = NA_character_,
        city_name = NA_character_, latitude = NA_real_, longitude = NA_real_, stringsAsFactors = FALSE
      )
    }
  }
}

relational_df <- bind_rows(extracted_rows)
unique_rors <- relational_df %>% filter(!is.na(institution_ror)) %>% distinct(institution_ror) %>% pull(institution_ror)
total_unique_rors <- length(unique_rors)

ror_names <- ror_types <- ror_countries <- ror_continents <- ror_cities <- rep(NA_character_, total_unique_rors)
ror_lats <- ror_longs <- rep(NA_real_, total_unique_rors)
names(ror_names) <- names(ror_types) <- names(ror_countries) <- names(ror_continents) <- names(ror_cities) <- names(ror_lats) <- names(ror_longs) <- unique_rors

# ------------------------------------------------------------------------------
# 5. EFFICIENT UNIQUE ROR API RESOLUTION
# ------------------------------------------------------------------------------
if (total_unique_rors > 0) {
  cat(sprintf("Resolving %d unique ROR registries...\n", total_unique_rors))
  pb <- progress_bar$new(format = "  Fetching ROR [:bar] :percent | ROR :current/:total | ETA: :eta", total = total_unique_rors, clear = FALSE, width = 100)
  
  for (k in seq_along(unique_rors)) {
    raw_ror <- unique_rors[k]
    ror_id <- str_extract(raw_ror, "0[a-z0-9]{8}")
    if (!is.na(ror_id)) {
      url <- paste0("https://api.ror.org/v2/organizations/", ror_id)
      response <- tryCatch({ GET(url, add_headers("User-Agent" = "EMBRC-Pipeline (mailto:davide.dicioccio@embrc.eu)"), timeout(5)) }, error = function(e) NULL)
      if (!is.null(response) && status_code(response) == 200) {
        parsed_data <- fromJSON(content(response, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
        names_list <- parsed_data$names
        if (!is.null(names_list) && length(names_list) > 0) {
          disp <- keep(names_list, ~ "ror_display" %in% .x$types)
          ror_names[raw_ror] <- if (length(disp) > 0) as.character(disp[[1]]$value)[1] else as.character(names_list[[1]]$value)[1]
        }
        if (!is.null(parsed_data$types) && length(parsed_data$types) > 0) ror_types[raw_ror] <- as.character(parsed_data$types[[1]])[1]
        loc_list <- parsed_data$locations
        if (!is.null(loc_list) && length(loc_list) > 0) {
          main_loc <- loc_list[[1]]
          ror_cities[raw_ror] <- as.character(main_loc$geonames_details$name)[1]
          ror_continents[raw_ror] <- as.character(main_loc$geonames_details$continent_name)[1]
          ror_countries[raw_ror] <- as.character(main_loc$geonames_details$country_name)[1]
          if (!is.null(main_loc$geonames_details$lat)) ror_lats[raw_ror] <- as.numeric(main_loc$geonames_details$lat)
          if (!is.null(main_loc$geonames_details$lng)) ror_longs[raw_ror] <- as.numeric(main_loc$geonames_details$lng)
        }
      }
    }
    pb$tick()
    Sys.sleep(0.08)
  }
  lookup_df <- data.frame(institution_ror = unique_rors, official_name = ror_names, institution_type = ror_types, official_country = ror_countries, continent_name = ror_continents, city_name = ror_cities, latitude = ror_lats, longitude = ror_longs, stringsAsFactors = FALSE)
  authors_final_df <- relational_df %>% select(-institution_type, -continent_name, -city_name, -latitude, -longitude, -country_name) %>% left_join(lookup_df, by = "institution_ror") %>% mutate(institution_name = ifelse(!is.na(official_name), official_name, institution_name), country_name = ifelse(!is.na(official_country), official_country, countrycode(toupper(str_trim(country_code)), origin = "iso2c", destination = "country.name"))) %>% select(-official_name, -official_country)
} else {
  authors_final_df <- relational_df %>% mutate(country_name = countrycode(toupper(str_trim(country_code)), origin = "iso2c", destination = "country.name"))
}

authors_final_df <- authors_final_df %>% 
  mutate(country_name = ifelse(is.na(country_name), countrycode(toupper(str_trim(country_code)), origin = "iso2c", destination = "country.name"), country_name))

# ------------------------------------------------------------------------------
# 6. MULTI-SHEET EXCEL WORKBOOK GENERATION
# ------------------------------------------------------------------------------
excel_sheets_list <- list(
  "publications" = validated_data,
  "auth&inst" = authors_final_df
)

write_xlsx(excel_sheets_list, output_file)
cat(sprintf("\nStep 5 complete. Workbook successfully saved to relative path: %s\n", output_file))