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

#' Get the concept set targets included in the concept sets
#'
#' @returns
#' A data frame with one row per concept set, and the following columns:
#' 
#' - **id**: A unique identifier. Use this when feeding the results in `evaluateConceptSets()`.
#' - **name**: The name of the clinical idea for which to generate the concept set.
#' - **definition**: A long free-text definition of the clinical idea, including the intended use of the concept set.
#' - **closestConceptId**: The concept ID of the concept that most closely matched the clinical idea.
#' - **closestConceptName**: The name of the concept that most closely matched the clinical idea.
#' 
#' @examples
#' getConceptSetTargets()
#' 
#' @export
getConceptSetTargets <- function() {
  conceptSetOverview <- read.csv(system.file("conceptSets.csv", package = "ConceptSetConstructionEvaluation"))
  conceptSetOverview$definition <- sapply(conceptSetOverview$definitionFile, .loadDefinition)

  targets <- conceptSetOverview |>
    select("id", 
           "name", 
           "definition", 
           "closestConceptId",
           "closestConceptName")
  return(targets)
}

.loadDefinition <- function(fileName) {
  definitionFile <- system.file("definitions", fileName, package = "ConceptSetConstructionEvaluation")
  definition <- paste(readLines(definitionFile), collapse = "\n")
  return(definition)
}
