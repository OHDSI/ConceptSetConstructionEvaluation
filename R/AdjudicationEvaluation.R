# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of ConceptSetConstructionEvaluation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Get concepts for concept adjudication evaluation
#'
#' @description
#' Get a set of concept set targets and candidate concepts for evaluating the process of concept adjudication 
#' (determining) whether a concept belongs to a concept set.
#' 
#' Use the `evaluateConceptAdjudication()` function to evaluate your adjudications of these concepts.
#' 
#' @returns
#' A data frame with the following columns:
#' 
#' - **targetName**: The name of the target for the concept set (what the concept set should be about).
#' - **targetDefinition**: A detailed description of the concept set target.
#' - **conceptId**: The concept ID of the candidate concept.
#' - **conceptName**: The name of the candidate concept. 
#' - **vocabularyId**: The vocabulary ID of the candidate concept. 
#' - **domainId**: The domain ID of the candidate concept. 
#' - **conceptClassId**: The concept class ID of the candidate concept. 
#' 
#' @export
getConceptsForAdjudication <- function() {
  concepts <- openxlsx::readWorkbook(system.file("goldStandard", "ConceptAdjudicationGoldStandard.xlsx", package = "ConceptSetConstructionEvaluation"))
  concepts <- concepts |>
    as_tibble() |>
    select("targetName", "targetDefinition", "conceptId", "conceptName", "vocabularyId", "domainId", "conceptClassId")
  return(concepts)
}

#' Evaluate concept adjudication
#' 
#' @param concepts The data frame returned by `getConceptsForAdjudication()` with an extra 'adjudication' column, having 
#'                 value 'YES' if the concept should be included in a concept set for the target, or 'NO' otherwise.
#'
#' @returns
#' A data frame with performance statistics.
#'
#' @examples
#' concepts <- getConceptsForAdjudication()
#' 
#' # Using random adjudication for this example:
#' concepts$adjudication <- sample(c("YES", "NO"), nrow(concepts), replace = TRUE)
#' 
#' evaluateConceptAdjudication(concepts)
#' 
#' @export
evaluateConceptAdjudication <- function(concepts) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(concepts, add = errorMessages)
  checkmate::assertNames(
    colnames(concepts),
    must.include = c(
      "targetName",
      "conceptId",
      "adjudication"
    ),
    add = errorMessages
  )
  if ("adjudication" %in% colnames(concepts)) {
    checkmate::assertSubset(concepts$adjudication, c("YES", "NO"))
  }
  checkmate::reportAssertions(collection = errorMessages)

  # goldStandard <- openxlsx::readWorkbook(system.file("goldStandard", 
  #                                                    "ConceptAdjudicationGoldStandard.xlsx", 
  #                                                    package = "ConceptSetConstructionEvaluation"))
  goldStandard <- readr::read_csv(system.file("goldStandard", 
                                                     "ConceptAdjudicationGoldStandard.csv", 
                                                     package = "ConceptSetConstructionEvaluation"),
                                  show_col_types = FALSE)
  
  
  goldStandard <- goldStandard |>
    left_join(concepts |>
                select("targetName", "conceptId", "adjudication"),
              by = join_by("targetName", "conceptId")) 
  if (any(is.na(goldStandard$adjudication))) {
    stop("Missing target - candidate concept combinations from the adjudications.",
         "Please return the same rows as received from getConceptsForAdjudication().")
  }  
  # For now treating PROXY as positive:
  confusion <- goldStandard |>
    mutate(tp = .data$adjudication == "YES" & .data$goldStandard != 'FALSE',
           fp = .data$adjudication == "YES" & .data$goldStandard == 'FALSE',
           tn = .data$adjudication == "NO" & .data$goldStandard == 'FALSE',
           fn = .data$adjudication == "NO" & .data$goldStandard != 'FALSE')
  confusionByDomain <- confusion |>
     group_by(.data$targetDomain) |>
    summarise(tp = sum(.data$tp),
              fp = sum(.data$fp),
              tn = sum(.data$tn),
              fn = sum(.data$fn)) 
  confusionOverall <- confusion |>
    summarise(tp = sum(.data$tp),
              fp = sum(.data$fp),
              tn = sum(.data$tn),
              fn = sum(.data$fn)) |>
    mutate(targetDomain = "All")
  performance <- bind_rows(
    confusionByDomain,
    confusionOverall
  ) |>
    mutate(ppv = .data$tp / (.data$tp + .data$fp),
           sensitivity = .data$tp / (.data$tp + .data$fn),
           specificity = .data$tn / (.data$tn + .data$fp))
  return(performance)
}