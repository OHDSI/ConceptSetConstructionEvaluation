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

#' Evaluate concept sets
#'
#' @param conceptSets The concept sets to evaluate. A data frame with two columns: `id`: the ID of the concept set, and
#'                    `conceptId`: the concept ID of the concept included in the concept set. Can contain 1 or more rows
#'                    per concept set.
#'
#' @returns
#' The evaluation of the concept sets
#' 
#' @examples
#' data(ai3ConceptSets)
#' results <- evaluateConceptSets(ai3ConceptSets)
#' results$f1ConservativeWeighted[results$id == "Total"]
#' 
#' @export
evaluateConceptSets <- function(conceptSets) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(conceptSets, add = errorMessages)
  checkmate::assertNames(
    colnames(conceptSets),
    must.include = c(
      "id",
      "conceptId"
    ),
    add = errorMessages
  )
  checkmate::reportAssertions(collection = errorMessages)
  conceptSetOverview <- read.csv(system.file("conceptSets.csv", package = "ConceptSetConstructionEvaluation"))
  
  ids <- unique(conceptSets$id)
  if (!all(ids %in% conceptSetOverview$id)) {
    stop("Unknown concept set IDs. Expected IDs ", 
         paste(conceptSetOverview$id, collapse = ", "), 
         ", but encounted ",
         paste(ids, collapse = ", "))
  }
  if (!all(conceptSetOverview$id %in% ids)) {
    warning("Did not find concept sets for all targets. Expected IDs ", 
            paste(conceptSetOverview$id, collapse = ", "), 
            ", but encounted ",
            paste(ids, collapse = ", "))
  }
  
  conceptPrevalence <- read.csv(system.file("conceptRecordCounts.csv", package = "ConceptSetConstructionEvaluation"))
  
  results <- lapply(conceptSetOverview$id,
                    .evaluateGroup, 
                    conceptSets = conceptSets,
                    conceptSetOverview = conceptSetOverview, 
                    conceptPrevalence = conceptPrevalence)
  results <- bind_rows(results)
  results <- results |>
    mutate(precision = .data$tps / (.data$tps + .data$fps),
           recall = .data$tps / (.data$tps + .data$fns),
           precisionConservative = .data$tps / (.data$tps + .data$fpsConservative),
           precisionWeighted = .data$tpsWeighted / (.data$tpsWeighted + .data$fpsWeighted),
           recallWeighted = .data$tpsWeighted / (.data$tpsWeighted + .data$fnsWeighted),
           precisionConservativeWeighted = .data$tpsWeighted / (.data$tpsWeighted + .data$fpsConservativeWeighted)) 
  total <- results |>
    summarise(
      tps = sum(.data$tps),
      fps = sum(.data$fps),
      tns = sum(.data$tns),
      fns = sum(.data$fns),
      fpsConservative = sum(.data$fpsConservative),
      tpsWeighted = sum(.data$tpsWeighted),
      fpsWeighted = sum(.data$fpsWeighted),
      tnsWeighted = sum(.data$tnsWeighted),
      fnsWeighted = sum(.data$fnsWeighted),
      fpsConservativeWeighted = sum(.data$fpsWeighted),
      precision = mean(.data$precision),
      recall = mean(.data$recall),
      precisionConservative = mean(.data$precisionConservative),
      precisionWeighted = mean(.data$precisionWeighted),
      recallWeighted = mean(.data$recallWeighted),
      precisionConservativeWeighted = mean(.data$precisionConservativeWeighted)
    ) |>
    mutate(id = "Total")
  
  results <- bind_rows(results, total) |>
    mutate(f1 = 2 * (.data$precision * .data$recall) / (.data$precision + .data$recall),
           f1Conservative = 2 * (.data$precisionConservative * .data$recall) / (.data$precisionConservative + .data$recall),
           f1Weighted = 2 * (.data$precisionWeighted * .data$recallWeighted) / (.data$precisionWeighted + .data$recallWeighted),
           f1ConservativeWeighted = 2 * (.data$precisionConservativeWeighted * .data$recallWeighted) / (.data$precisionConservativeWeighted + .data$recallWeighted))
  return(results)
}

# id <- conceptSetOverview$id[1]
.evaluateGroup <- function(id, conceptSets, conceptSetOverview, conceptPrevalence) {
  group <- conceptSets |>
    filter(.data$id == !!id)
  goldStandardAdjudicatedFile <- conceptSetOverview |>
    filter(.data$id == !!id) |>
    pull(.data$goldStandardAdjudicatedFile)
  goldStandardAdjudicated <- openxlsx::read.xlsx(system.file("goldStandard", 
                                                             goldStandardAdjudicatedFile, 
                                                             package = "ConceptSetConstructionEvaluation"))
  goldStandardIntersectionFile <- conceptSetOverview |>
    filter(.data$id == !!id) |>
    pull(.data$goldStandardIntersectionFile)
  goldStandardIntersection <- read.csv(system.file("goldStandard", 
                                                   goldStandardIntersectionFile, 
                                                   package = "ConceptSetConstructionEvaluation"))
  goldPositiveIds <- c(goldStandardIntersection$conceptId,
                       goldStandardAdjudicated |>
                         filter(.data$keepConceptSet == "YES") |>
                         pull(.data$conceptId)
  )
  goldNegativeIds <- goldStandardAdjudicated |>
    filter(.data$keepConceptSet != "YES") |>
    pull(.data$conceptId)
  tps <- group$conceptId[group$conceptId %in% goldPositiveIds]
  fps <- group$conceptId[group$conceptId %in% goldNegativeIds]
  tns <- goldNegativeIds[!goldNegativeIds %in% group$conceptId]
  fns <- goldPositiveIds[!goldPositiveIds %in% group$conceptId]
  # Conservative: any concepts included in the proposed concept sets that were never adjudicated are considered false 
  # positives:
  fpsConservative <- group$conceptId[!group$conceptId %in% goldPositiveIds]
  
  tpsWeighted <- .weightByPrevalence(tps, conceptPrevalence)
  fpsWeighted <- .weightByPrevalence(fps, conceptPrevalence)
  tnsWeighted <- .weightByPrevalence(tns, conceptPrevalence)
  fnsWeighted <- .weightByPrevalence(fns, conceptPrevalence)
  fpsConservativeWeighted <- .weightByPrevalence(fpsConservative, conceptPrevalence)
  
  result <- tibble(
    id = group$id[1],
    tps = length(tps),
    fps = length(fps),
    tns = length(tns),
    fns = length(fns),
    fpsConservative = length(fpsConservative),
    tpsWeighted = tpsWeighted,
    fpsWeighted = fpsWeighted,
    tnsWeighted = tnsWeighted,
    fnsWeighted = fnsWeighted,
    fpsConservativeWeighted = fpsConservativeWeighted
  )
  
  return(result)
}

.weightByPrevalence <- function(conceptIds, conceptPrevalence) {
  counts <- conceptPrevalence |>
    filter(.data$concept_id %in% conceptIds) |>
    pull(.data$record_count) 
  return(sum(log(1 + counts)))
}

