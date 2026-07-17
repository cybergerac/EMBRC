# EMBRC Bibliographic Analysis Pipeline

This repository contains the modular data pipeline designed for the European Marine Biological Resource Centre (EMBRC) to retrieve, process, audit, and enrich institutional publication records from 2018 to 2026. 

The toolkit is engineered to provide structured data exports that fulfill the key performance indicators (KPIs) required by ESFRI monitoring cycles, while fully respecting modern Open Science and DORA assessment principles through integrated alternative metric signals.

ℹ️ **Lineage Note:** This tool is an evolution and adaptation of the original code developed by Christina Pavloudi, rewritten to support the new institutional classification, cloud AI validation, and native Crossref, OpenAlex, and OpenAIRE enrichment without depending on archived external libraries.

---

## 🛠️ Pipeline Structure

The workflow is broken down into five standalone, sequential modules managed by a single orchestrator script:

### ⚙️ ORCHESTRATOR | EMBRC_publications_0_pipeline.R
* **Role:** The master conductor script.
* **Function:** It coordinates the execution of the entire pipeline, calling each submodule in the correct sequence using native R routing operations while tracking global runtime metrics.

### 📥 STEP 1: RETRIEVER | EMBRC_publications_1_retriever.R
* **Role:** The web data extraction module.
* **Function:** It queries international bibliographic repositories (OpenAlex) using specific project strings (e.g., "EMO-BON"), unnesting deeply layered JSON payloads to isolate raw authors, parenthetical ORCIDs, and initial institution strings.

### 🧼 STEP 2: CLEANER | EMBRC_publications_2_cleaner.R
* **Role:** Database standardization and validation tag normalization.
* **Function:** It processes the historical master dataset by stripping malformed HTML tags from text fields, refining messy abstract entries, and organizing validation status tags into structured factors to push excluded entries to the bottom.

### 🧠 STEP 3: AI ENRICHER | EMBRC_publications_3_enricher_AI.R
* **Role:** AI classification and marine biology topic mapping.
* **Function:** For any review-required entry, it routes titles and abstracts to the Google Gemini API to semantically evaluate and exclude out-of-scope papers, automatically mapping valid records to our institutional marine biology taxonomy.

### 📊 STEP 4: METRICS | EMBRC_publications_4_metrics.R
* **Role:** Rich citation and Open Access tracking.
* **Function:** It processes unique validated DOIs to fetch live citation numbers from OpenAlex and queries the OpenAIRE graph API to resolve and standardize open-access compliance codes into clean categories.

### 🗺️ STEP 5: EXTRACTOR | EMBRC_publications_5_authors_extractor.R
* **Role:** Relational institution parsing and Excel deliverable generation.
* **Function:** It explodes multi-author text fields into clean relational nodes, resolving unique ROR identifiers through API calls to fetch official institution names, entity types, cities, and precise coordinates while fallback geographies are resolved dynamically.

---

## 🚀 How to Run the Pipeline

To execute the entire workflow locally or inside Dropbox, follow these steps:

1. **Environment Preparation:** Ensure your R environment has all necessary libraries installed (`dplyr`, `stringr`, `readr`, `purrr`, `httr`, `jsonlite`, `progress`, `writexl`, `countrycode`). Make sure your Gemini API key is configured in your system environment.
2. **Directory Context:** Open RStudio and ensure your working directory is set to the source script location (**Session > Set Working Directory > To Source File Location**). This allows the system to resolve the internal `output_csv/` path without hardcoded disk letters.
3. **Execution:** Run the master orchestrator script directly from the R console:

```R
source("EMBRC_publications_0_pipeline.R")
