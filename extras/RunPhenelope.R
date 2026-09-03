# remove.packages("Phenelope")
# remotes::install_github("ohdsi/Phenelope", ref = "develop")

library(ConceptSetConstructionEvaluation)
library(Phenelope)
library(dplyr)

llmClientO3 <- ellmer::chat_azure_openai(
  endpoint = gsub("/openai/deployments.*", "", keyring::key_get("genai_o3_endpoint")),
  api_version = "2024-12-01-preview",
  model = "o3",
  credentials = function() keyring::key_get("genai_api_gpt4_key")
)

llmClient4o <- ellmer::chat_azure_openai(
  endpoint = gsub("/openai/deployments.*", "", keyring::key_get("genai_gpt4o_endpoint")),
  api_version = "2023-03-15-preview",
  model = "gpt-4o",
  credentials = function() keyring::key_get("genai_api_gpt4_key")
)
folder <- "e:/temp/phenelopeEval3"

cdmDatabaseSchema <- "merative_ccae.cdm_merative_ccae_v3789"

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "spark",
  connectionString = keyring::key_get("databricksConnectionString"),
  user = "token",
  password = keyring::key_get("databricksToken")
)
options(sqlRenderTempEmulationSchema = "scratch.scratch_mschuemi")

# Create concept sets for gold standard targets ------------------------------------------------------------------------
dir.create(folder, recursive = TRUE)

targets <- getConceptSetTargets()
conceptSets <- list()
for (i in seq_len(nrow(targets))) {
  targetRow <- targets[i, ]
  fileName <- file.path(folder, sprintf("ConceptSet_%s.csv", targetRow$id))
  workFolder <- file.path(folder, sprintf("WorkFolder_%s", targetRow$id))
  if (!file.exists(fileName)) {
    message("Creating concept set for ", targetRow$name)
    llmClient <- llmClientO3
    conceptSet <- createConceptSet(conceptSetTarget = targetRow$name,
                                   originalConceptList = targetRow$closestConceptId,
                                   clinicalDefinition = targetRow$definition,
                                   llmClientNonReasoning = llmClient4o,
                                   llmClientReasoning = llmClientO3,
                                   connectionDetails = connectionDetails,
                                   cdmDatabaseSchema = cdmDatabaseSchema,
                                   outputDirectory = workFolder)
    # conceptSet <- createConceptSet(conceptName = targetRow$name,
    #                                originalConceptList = targetRow$closestConceptId,
    #                                additionalInformation = targetRow$definition,
    #                                llmClient = llmClient4o,
    #                                connectionDetails = connectionDetails,
    #                                cdmDatabaseSchema = cdmDatabaseSchema,
    #                                outputDirectory = workFolder)
    saveRDS(conceptSet, fileName)
  } else {
    conceptSet <- readRDS(fileName)
  }
  conceptSets[[i]] <- conceptSet$testedConcepts |>
    filter(finalAnswer == "YES") |>
    select("conceptId") |>
    mutate(id = targetRow$id)
  
}
conceptSets <- lapply(conceptSets, function(x) {x$conceptId <- as.integer(x$conceptId); return(x)})
conceptSets <- bind_rows(conceptSets)

# Evaluate against gold standard ---------------------------------------------------------------------------------------
results <- evaluateConceptSets(conceptSets)
results$f1ConservativeWeighted[results$id == "Total"]

# Phenelope 0.1.2 ------------------------------------
# 4o:
# [1] 0.865392

# 4o rerun (no changes):
# [1] 0.8267172

# 4o rerun (no changes, morning Europe):
# [1] 0.8431821 

# o3:
# [1] 0.8318164

# Some August develop version -------------------------------------------------
# 4o + o3:
# [1] 0.8044064

# Sep 3 develop version --------------------------------------------------------
# 4o + o3:
# [1] 0.8144267
