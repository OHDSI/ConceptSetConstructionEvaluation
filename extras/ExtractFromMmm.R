library(dplyr)

folder <- "/Users/schuemie/git/MindMeetsMachines/Materials/Scripts/results/phaseA_arm_concept_matrix"
columnToExtract <- "AI3"

files <- list.files(folder)

ai3ConceptSets <- list()

# file = files[1]
for (file in files) {
  id <- gsub("_.*", "", file)
  table <- read.csv(file.path(folder, file))
  includedConceptIds <- table$conceptId[table[, columnToExtract] == 1]    
  ai3ConceptSets[[length(ai3ConceptSets) + 1]] <- tibble(id = id,
                                                       conceptId = includedConceptIds)
}
ai3ConceptSets <- bind_rows(ai3ConceptSets)
save(ai3ConceptSets, file = "data/ai3ConceptSets.RData")
