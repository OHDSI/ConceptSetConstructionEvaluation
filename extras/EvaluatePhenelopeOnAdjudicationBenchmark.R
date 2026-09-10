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

# Evaluation function --------------------------------------------------------------------------------------------------
evaluateAdjudicator <- function(conceptAdjudicator) {
  concepts <- getConceptsForAdjudication()
  groups <- concepts |>
    group_by(targetName) |>
    group_split()
  
  start <- Sys.time()
  costTracker <- new.env()
  costTracker$amount <- 0
  adjudications <- list()
  for (i in seq_along(groups)) {
    message(sprintf("Group %d of %d", i, length(groups)))
    group <- asConcepts(groups[[i]], origin = "SEED", status = "UNADJUDICATED")
    adjudications[[i]] <- conceptAdjudicator$adjudicateConcepts(
      concepts = group,
      name = group$targetName[1],
      clinicalDefinition = group$targetDefinition[1],
      llmClient = llmClient,
      costTracker = costTracker
    )  
  }
  adjudications <- bind_rows(adjudications) |>
    mutate(adjudication = if_else(status == "APPROVED", "YES", "NO"))
  delta <- Sys.time() - start
  message("Adjudicating concepts took ", signif(delta, 3), " ", attr(delta, "units"), " and cost $", costTracker$amount, ".")
  
  return(evaluateConceptAdjudication(adjudications))
}

# Using default prompts in refactored Phenelope ---------------------------------------------------------------
conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 99999)
evaluateAdjudicator(conceptAdjudicator)

# First run:
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       90    12   480    18 0.882       0.833       0.976
# MEASUREMENT     57     3   230    10 0.95        0.851       0.987
# PROCEDURE       73     9   306    12 0.890       0.859       0.971
# All            220    24  1016    40 0.902       0.846       0.977

# Second run:
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       86    18   474    22 0.827       0.796       0.963
# MEASUREMENT     49     4   229    18 0.925       0.731       0.983
# PROCEDURE       72    11   304    13 0.867       0.847       0.965
# All            207    33  1007    53 0.862       0.796       0.968

# Third run:
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       89    17   475    19 0.840       0.824       0.965
# MEASUREMENT     54     5   228    13 0.915       0.806       0.979
# PROCEDURE       71     7   308    14 0.910       0.835       0.978
# All            214    29  1011    46 0.881       0.823       0.972

# Fourth run:
# Adjudicating concepts took 30.2 mins and cost $1.55179.
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       87    14   478    21 0.861       0.806       0.972
# MEASUREMENT     55    12   221    12 0.821       0.821       0.948
# PROCEDURE       70    10   305    15 0.875       0.824       0.968
# All            212    36  1004    48 0.855       0.815       0.965

# Using V1 prompt ---------------------------------------------------------------------------------------------------
prompt <- paste(readLines("extras/Adjudication.txt"), collapse = "\n")
systemPrompt <- paste(readLines("extras/AdjudicationSystem.txt"), collapse = "\n")
conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 99999,
                                                    prompt = prompt,
                                                    systemPrompt = systemPrompt)

evaluateAdjudicator(conceptAdjudicator)

# First run:
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       87    15   477    21 0.853       0.806       0.970
# MEASUREMENT     53     6   227    14 0.898       0.791       0.974
# PROCEDURE       73     9   306    12 0.890       0.859       0.971
# All            213    30  1010    47 0.877       0.819       0.971

# Second run:
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       88    12   480    20 0.88        0.815       0.976
# MEASUREMENT     55     2   231    12 0.965       0.821       0.991
# PROCEDURE       71    14   301    14 0.835       0.835       0.956
# All            214    28  1012    46 0.884       0.823       0.973

# Third run:
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       90    15   477    18 0.857       0.833       0.970
# MEASUREMENT     49     8   225    18 0.860       0.731       0.966
# PROCEDURE       70    10   305    15 0.875       0.824       0.968
# All            209    33  1007    51 0.864       0.804       0.968

# Fourth run: 
# Adjudicating concepts took 57.7 mins and cost $1.53819.
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       88    14   478    20 0.863       0.815       0.972
# MEASUREMENT     51     3   230    16 0.944       0.761       0.987
# PROCEDURE       73    13   302    12 0.849       0.859       0.959
# All            212    30  1010    48 0.876       0.815       0.971

# Using V1 prompt and quick screen ----------------------------------------------------------------------------------
prompt <- paste(readLines("extras/Adjudication.txt"), collapse = "\n")
systemPrompt <- paste(readLines("extras/AdjudicationSystem.txt"), collapse = "\n")
quickScreenPrompt <- paste(readLines("extras/QuickScreen.txt"), collapse = "\n")
quickScreenSystemPrompt <- paste(readLines("extras/QuickScreenSystem.txt"), collapse = "\n")
conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 1,
                                                    prompt = prompt,
                                                    systemPrompt = systemPrompt,
                                                    quickScreenPrompt = quickScreenPrompt,
                                                    quickScreenSystemPrompt = quickScreenSystemPrompt)

evaluateAdjudicator(conceptAdjudicator)

# Adjudicating concepts took 22.9 mins and cost $1.75825.
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       87    12   480    21 0.879       0.806       0.976
# MEASUREMENT     50     3   230    17 0.943       0.746       0.987
# PROCEDURE       66     7   308    19 0.904       0.776       0.978
# All            203    22  1018    57 0.902       0.781       0.979

# Using V2 prompt ---------------------------------------------------------------------------------------------------
prompt <- paste(readLines("extras/AdjudicationV2.txt"), collapse = "\n")
systemPrompt <- paste(readLines("extras/AdjudicationSystem.txt"), collapse = "\n")
conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 99999,
                                                    prompt = prompt,
                                                    systemPrompt = systemPrompt)

evaluateAdjudicator(conceptAdjudicator)
# First run
# Adjudicating concepts took 19.3 mins and cost $1.564762.
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       88    15   477    20 0.854       0.815       0.970
# MEASUREMENT     51     8   225    16 0.864       0.761       0.966
# PROCEDURE       67    10   305    18 0.870       0.788       0.968
# All            206    33  1007    54 0.862       0.792       0.968

# Second run
# Adjudicating concepts took 18.6 mins and cost $1.542562.
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       86    16   476    22 0.843       0.796       0.967
# MEASUREMENT     56     5   228    11 0.918       0.836       0.979
# PROCEDURE       68    12   303    17 0.85        0.8         0.962
# All            210    33  1007    50 0.864       0.808       0.968

# Using V1 prompt and quick screen V2 -------------------------------------------------------------------------------
prompt <- paste(readLines("extras/Adjudication.txt"), collapse = "\n")
systemPrompt <- paste(readLines("extras/AdjudicationSystem.txt"), collapse = "\n")
quickScreenPrompt <- paste(readLines("extras/QuickScreenV2.txt"), collapse = "\n")
quickScreenSystemPrompt <- paste(readLines("extras/QuickScreenSystem.txt"), collapse = "\n")
conceptAdjudicator <- DefaultConceptAdjudicator$new(nForQuickScreen = 1,
                                                    prompt = prompt,
                                                    systemPrompt = systemPrompt,
                                                    quickScreenPrompt = quickScreenPrompt,
                                                    quickScreenSystemPrompt = quickScreenSystemPrompt)

evaluateAdjudicator(conceptAdjudicator)

# Adjudicating concepts took 21 mins and cost $1.519192.
# targetDomain    tp    fp    tn    fn   ppv sensitivity specificity
# CONDITION       86    13   479    22 0.869       0.796       0.974
# MEASUREMENT     47     2   231    20 0.959       0.701       0.991
# PROCEDURE       69     5   310    16 0.932       0.812       0.984
# All            202    20  1020    58 0.910       0.777       0.981

