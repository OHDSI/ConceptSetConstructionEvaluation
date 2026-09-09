# To install refactored Phenelope to use separate DefaultConceptAdjudicator class:
# remotes::install_github("schuemie/Phenelope", ref = "refactor")

library(ConceptSetConstructionEvaluation)
library(Phenelope)
library(dplyr)

llmClient <- ellmer::chat_azure_openai(
  endpoint = keyring::key_get("genai_openai_endpoint"),
  api_version = "2024-12-01-preview",
  model = "o3",
  credentials = function() keyring::key_get("genai_api_gpt4_key")
)
folder <- "e:/temp/phenelopeEvalRefactor"

# Using default prompts in refactored Phenelope ---------------------------------------------------------------
concepts <- getConceptsForAdjudication()

groups <- concepts |>
  group_by(targetName) |>
  group_split()

conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 99999)

adjudications <- list()
for (i in seq_along(groups)) {
  message(sprintf("Group %d of %d", i, length(groups)))
  group <- asConcepts(groups[[i]], origin = "SEED", status = "UNADJUDICATED")
  adjudications[[i]] <- conceptAdjudicator$adjudicateConcepts(
    concepts = group,
    name = group$targetName[1],
    clinicalDefinition = group$targetDefinition[1],
    llmClient = llmClient
  )  
}
adjudications <- bind_rows(adjudications) |>
  mutate(adjudication = if_else(status == "APPROVED", "YES", "NO"))

evaluateConceptAdjudication(adjudications)
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       90    12   480    18 0.882       0.833       0.976
# MEASUREMENT     57     3   230    10 0.95        0.851       0.987
# PROCEDURE       73     9   306    12 0.890       0.859       0.971
# All            220    24  1016    40 0.902       0.846       0.977

# Using Other prompt ---------------------------------------------------------------
prompt <- paste(readLines("extras/NewAdjudicationPrompt.txt"), collapse = "\n")
systemPrompt <- "You are an expert medical doctor specializing in healthcare data analysis. Your primary function is to analyze healthcare data, including electronic health records, to infer causal relationships between exposures and health outcomes."

concepts <- getConceptsForAdjudication()

groups <- concepts |>
  group_by(targetName) |>
  group_split()

conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 99999,
                                                    prompt = prompt,
                                                    systemPrompt = systemPrompt)

adjudications <- list()
for (i in seq_along(groups)) {
  message(sprintf("Group %d of %d", i, length(groups)))
  group <- asConcepts(groups[[i]], origin = "SEED", status = "UNADJUDICATED")
  adjudications[[i]] <- conceptAdjudicator$adjudicateConcepts(
    concepts = group,
    name = group$targetName[1],
    clinicalDefinition = group$targetDefinition[1],
    llmClient = llmClient
  )  
}
temp = adjudications
adjudications <- bind_rows(adjudications) |>
  mutate(adjudication = if_else(status == "APPROVED", "YES", "NO"))

evaluateConceptAdjudication(adjudications)
