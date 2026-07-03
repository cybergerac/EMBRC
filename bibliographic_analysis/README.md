# EMBRC Bibliographic Analysis Pipeline

This repository contains the modular data pipeline designed for the European Research Infrastructure of Marine Biological Resources (**EMBRC**) to retrieve, process, deduplicate, and enrich institutional publication records from **2018 to 2026**. 

The toolkit is engineered to provide structured data exports that fulfill the key performance indicators (**KPIs**) required by **ESFRI monitoring cycles**, while fully respecting modern **Open Science** and **DORA** assessment principles through integrated alternative metric signals.

> ℹ️ **Lineage Note:** This tool is an evolution and adaptation of the original code developed by Christina Pavloudi, rewritten to support the new institutional classification and native Altmetrics enrichment without depending on archived external libraries. Source file is here: https://github.com/cpavloud/retrieve_publications/blob/main/Retrieve_publications.R

---

## 🛠️ Pipeline Structure

The workflow is broken down into three standalone, sequential modules managed by a single orchestrator script:

*   **`EMBRC_publications_0_pipeline.R`**
    *   **Role:** The master conductor script.
    *   **Function:** It coordinates the execution of the entire pipeline, calling each submodule in the correct sequence using native R routing operations.
*   **`EMBRC_publications_1_retriever.R`**
    *   **Role:** The web data extraction module.
    *   **Function:** It queries international bibliographic repositories (Crossref and Semantic Scholar) using strict institutional string matching, cleans HTML/XML text noise, and stores individual raw CSV chunks in a temporary folder.
*   **`EMBRC_publications_2_merger.R`**
    *   **Role:** The compilation and consolidation phase.
    *   **Function:** It unifies the raw CSV chunks, executes cross-source historical deduplication based on unique DOIs and normalized titles, tracks the original query provenance tags, and computes structural ESFRI metrics (such as author team sizes and proxies for international collaboration).
*   **`EMBRC_publications_3_altmetrics.R`**
    *   **Role:** The societal impact enrichment module.
    *   **Function:** It isolates the validated publication DOIs to query the public Altmetric.com API natively, appending real-time public attention scores and counting direct scientific citations inside international policy frameworks.

---

## 🚀 How to Run the Pipeline

To execute the entire workflow locally, follow these simple steps:

1.  **Environment Preparation:** Place all four scripts (`0_pipeline`, `1_retriever`, `2_merger`, `3_altmetrics`) in your main R working directory.
2.  **Network Check:** Ensure your local machine has an active internet connection to communicate with the bibliographic and Altmetric servers.
3.  **Execution:** Open and source the main orchestrator script `EMBRC_publications_0_pipeline.R` inside RStudio.
4.  **Output:** The pipeline will automatically handle folder creation, raw data downloading, deduplication, and API fetching. 

The final consolidated asset will be generated in your main directory as a single unified master file named:
`EMBRC_master_enriched_publications.csv`
