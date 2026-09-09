# remove.packages("Phenelope")
# remotes::install_github("ohdsi/Phenelope", ref = "develop")

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


# Using Joel's prompts ---------------------------------------------------------------
prompt <- paste(readLines("extras/NewAdjudicationPrompt.txt"), collapse = "\n")
systemPrompt <- "You are an expert medical doctor specializing in healthcare data analysis. Your primary function is to analyze healthcare data, including electronic health records, to infer causal relationships between exposures and health outcomes."

concepts <- getConceptsForAdjudication()

groups <- concepts |>
  group_by(targetName) |>
  group_split()

conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 99999,
                                                    prompt = joelsPrompt,
                                                    systemPrompt = joelsSystemPrompt)

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

# missing <- concepts |>
#   anti_join(adjudications)
# group <- concepts |>
#   filter(targetName == "Albumin measurement, serum") |>
#   asConcepts(origin = "SEED", status = "UNADJUDICATED")
# x  <- conceptAdjudicator$adjudicateConcepts(
#   concepts = group,
#   name = group$targetName[1],
#   clinicalDefinition = group$targetDefinition[1],
#   llmClient = llmClient
# )
# 
# 
# targetNames <- concepts$targetName[!duplicated(concepts$targetName)]
# which(targetNames == "Albumin measurement, serum")
# adjudications <- temp
# adjudications[[5]] <- x
