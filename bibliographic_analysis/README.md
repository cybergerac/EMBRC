EMBRC Bibliographic Analysis Pipeline
This repository contains the modular data pipeline designed for the European Marine Biological Resource Centre (EMBRC) to retrieve, process, audit, and enrich institutional publication records from 2018 to 2026.

The toolkit is engineered to provide structured data exports that fulfill the key performance indicators (KPIs) required by ESFRI monitoring cycles, while fully respecting modern Open Science and DORA assessment principles through integrated alternative metric signals (policy impact, patents, and media coverage).

ℹ️ Lineage Note: This tool is an evolution and adaptation of the original code developed by Christina Pavloudi, rewritten to support the new institutional classification, local LLM validation, and native Altmetrics enrichment without depending on archived external libraries. Source file is here: cpavloud/retrieve_publications.

🛠️ Pipeline Structure
The workflow is broken down into three standalone, sequential modules managed by a single orchestrator script:

EMBRC_publications_0_pipeline.R
Role: The master conductor script.

Function: Coordinates the execution of the entire pipeline, setting up directories and calling each submodule in the correct sequence using native R routing operations.

EMBRC_publications_1_retriever.R
Role: The web data extraction module.

Function: Queries international bibliographic repositories (CrossRef and Semantic Scholar) using strict institutional string matching, unnests deeply layered JSON lists to extract missing author affiliations, and stores individual raw CSV chunks in a designated output_csv/ subfolder.

EMBRC_publications_2_AIcleaner.R
Role: The compilation, deduplication, and AI semantic auditing phase.

Function: Unifies the raw CSV chunks and executes cross-source historical deduplication based on unique DOIs and normalized titles. It handles advanced text refinement (fixing malformed abstract strings) and flags ambiguous acronym matches. For uncertain records, it routes data via local HTTP requests to a containerized Gemma 4:12b model to semantically screen and eliminate out-of-scope false positives.

EMBRC_publications_3_altmetrics.R
Role: The societal impact enrichment module.

Function: Isolates the validated publication DOIs to query the public Altmetric API natively using sequential rate-limited calls, appending real-time public attention scores and tracking direct scientific citations inside international policy frameworks, government white papers, and global patents.

🚀 How to Run the Pipeline
1. Prerequisites & Environment Setup
Local AI Instance: Ensure Docker Desktop is open and running. Your local Ollama container must be active, hosting the gemma4:12b model image (ollama pull gemma4:12b).

Script Location: Place all four scripts (0_pipeline, 1_retriever, 2_AIcleaner, 3_altmetrics) in your main R working directory: D:/coding/EMBRC_publications/scripts.

2. Execution
Open RStudio and set your working directory to the scripts folder, then source the main orchestrator script directly from the R console:
