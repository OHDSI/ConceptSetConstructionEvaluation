# remove.packages("Phenelope")
# remotes::install_github("ohdsi/Phenelope", ref = "develop")
# remotes::install_github("ohdsi/Phenelope")

library(ConceptSetConstructionEvaluation)
library(Phenelope)
library(dplyr)

llmClient <- ellmer::chat_azure_openai(
  endpoint = keyring::key_get("genai_openai_endpoint"),
  api_version = "2024-12-01-preview",
  model = "o3",
  credentials = function() keyring::key_get("genai_api_gpt4_key")
)
# llmClient <- ellmer::chat_azure_openai(
#   endpoint = keyring::key_get("genai_openai_endpoint"),
#   api_version = "2023-03-15-preview",
#   model = "gpt-4o",
#   credentials = function() keyring::key_get("genai_api_gpt4_key")
# )
folder <- "e:/temp/phenelopeRefactorV1Prompts"

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
    # debugonce(createConceptSet)
    # debugonce(Phenelope:::.fullConceptSetCreation)
    # conceptSet <- createConceptSet(conceptSetTarget = targetRow$name,
    #                                originalConceptList = targetRow$closestConceptId,
    #                                clinicalDefinition = targetRow$definition,
    #                                llmClientReasoning = llmClient,
    #                                connectionDetails = connectionDetails,
    #                                cdmDatabaseSchema = cdmDatabaseSchema,
    #                                outputDirectory = workFolder)
    conceptSet <- createConceptSet(name = targetRow$name,
                                   clinicalDefinition = targetRow$definition,
                                   seedConceptIds = targetRow$closestConceptId,
                                   llmClient = llmClient,
                                   connectionDetails = connectionDetails,
                                   vocabDatabaseSchema = cdmDatabaseSchema,
                                   conceptAdjudicator = DefaultConceptAdjudicator$new(nForQuickScreen = 500),
                                   cacheFolder = workFolder)
    conceptSet <- readr::read_csv(file.path(workFolder, "FinalConcepts.csv"), show_col_types = FALSE)
    
    saveRDS(conceptSet, fileName)
  } else {
    conceptSet <- readRDS(fileName)
  }
  conceptSets[[i]] <- conceptSet |>
    filter(status == "APPROVED") |>
    select("conceptId") |>
    mutate(id = targetRow$id)
  # conceptSets[[i]] <- conceptSet$testedConcepts |>
  #   filter(finalAnswer == "YES") |>
  #   select("conceptId") |>
  #   mutate(id = targetRow$id)
  
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

# o3:
# [1] 0.8314662
# id      tps   fps   tns   fns fpsConservative tpsWeighted fpsWeighted tnsWeighted fnsWeighted fpsConservativeWeighted precision recall precisionConservative precisionWeighted recallWeighted
# C01      42     5    52     9               5       111.          0         99.4         14.4                     0       0.894  0.824                 0.894             1              0.885
# C02     195     1     5     9               4       448.          0          0           20.2                    11.9     0.995  0.956                 0.980             1              0.957
# C03      26     0     0     8               0        81.7         0          0           28.4                     0       1      0.765                 1                 1              0.742
# C04      62   115    29     1             171       176.        170.        76.6          0                     265.      0.350  0.984                 0.266             0.510          1    
# C06     109     0   114    90               0       206.          0        173.         119.                      0       1      0.548                 1                 1              0.634
# C07      21     9     8    13               9        67.1        19.7        7.03        40.7                    19.7     0.7    0.618                 0.7               0.773          0.622
# Total   455   130   208   130             189      1090.        189.       356.         222.                    189.      0.823  0.782                 0.807             0.880          0.807


# After refactoring --------------------------------------------------------------
# Using provided seed concept
# [1] 0.7193594

# Using provided seed concept, Joel's prompt, no quick screen:
# [1] 0.7865279
# Rerunning without change:
# [1] 0.7994181

# Using provided seed concept, Joel's prompt, no quick screen, 4o:
# [1] 0.7371567

# Using provided seed concept, Joel's exact prompt, o3:
# [1] 0.7797676

# Using provided seed concept, Joel's exact prompt, o3, setting excluded to None:
# [1] 0.7844916
# id      tps   fps   tns   fns fpsConservative tpsWeighted fpsWeighted tnsWeighted fnsWeighted fpsConservativeWeighted precision recall precisionConservative precisionWeighted recallWeighted
# C01      42     3    54     9               3       111.          0         99.4         14.4                     0       0.933  0.824                 0.933             1              0.885
# C02     188     1     5    16               1       385.          0          0           83.1                     0       0.995  0.922                 0.995             1              0.823
# C03      30     0     0     4               0        91.5         0          0           18.7                     0       1      0.882                 1                 1              0.830
# C04      55   109    35     8             168       124.        157.        88.9         52.4                   250.      0.335  0.873                 0.247             0.441          0.703
# C06      81     1   113   118               1       163.          0        173.         161.                      0       0.988  0.407                 0.988             1              0.504
# C07      21    10     7    13              10        67.1        19.7        7.03        40.7                    19.7     0.677  0.618                 0.677             0.773          0.622
# Total   417   124   214   168             183       942.        177.       369.         370.                    177.      0.821  0.754                 0.807             0.869          0.728

# Using provided seed concept, Joel's exact prompt, o3, setting excluded to None, same concept JSON, filtering by string:
# [1] 0.7986
# id      tps   fps   tns   fns fpsConservative tpsWeighted fpsWeighted tnsWeighted fnsWeighted fpsConservativeWeighted precision recall precisionConservative precisionWeighted recallWeighted precisionConservativeWe…¹    f1 f1Conservative f1Weighted
# C01      43     3    54     8               4       111.          0         99.4         14.4                     0       0.935  0.843                 0.915             1              0.885                     1     0.887          0.878      0.939
# C02     188     1     5    16               1       376.          0          0           93.0                     0       0.995  0.922                 0.995             1              0.802                     1     0.957          0.957      0.890
# C03      27     0     0     7               0        81.7         0          0           28.4                     0       1      0.794                 1                 1              0.742                     1     0.885          0.885      0.852
# C04      60   113    31     3             173       159.        170.        76.6         16.9                   265.      0.347  0.952                 0.258             0.485          0.904                     0.375 0.508          0.405      0.631
# C06      97     0   114   102               0       171.          0        173.         154.                      0       1      0.487                 1                 1              0.526                     1     0.655          0.655      0.689
# C07      16     7    10    18               7        67.1        19.7        7.03        40.7                    19.7     0.696  0.471                 0.696             0.773          0.622                     0.773 0.561          0.561      0.690
# Total   431   124   214   154             185       965.        189.       356.         347.                    189.      0.829  0.745                 0.810             0.876          0.747                     0.858 0.785          0.776      0.806

# Using provided seed concept, Joel's exact prompt, o3, setting excluded to None, same concept JSON, filtering by string, dropping concept class filter:
# [1] 0.7814644
# id      tps   fps   tns   fns fpsConservative tpsWeighted fpsWeighted tnsWeighted fnsWeighted fpsConservativeWeighted precision recall precisionConservative precisionWeighted recallWeighted precisionConservativeWe…¹    f1 f1Conservative f1Weighted
# C01      43     4    53     8               4       111.          0         99.4         14.4                     0       0.915  0.843                 0.915             1              0.885                     1     0.878          0.878      0.939
# C02     196     1     5     8               3       458.          0          0           10.4                     0       0.995  0.961                 0.985             1              0.978                     1     0.978          0.973      0.989
# C03      27     0     0     7               0        81.7         0          0           28.4                     0       1      0.794                 1                 1              0.742                     1     0.885          0.885      0.852
# C04      57   102    42     6             151       134.        143.       103.          42.3                   224.      0.358  0.905                 0.274             0.483          0.760                     0.374 0.514          0.421      0.591
# C06      56     0   114   143               0       103.          0        173.         221.                      0       1      0.281                 1                 1              0.318                     1     0.439          0.439      0.483
# C07      21    10     7    13              10        67.1        19.7        7.03        40.7                    19.7     0.677  0.618                 0.677             0.773          0.622                     0.773 0.646          0.646      0.690
# Total   400   117   221   185             168       955.        163.       383.         357.                    163.      0.824  0.734                 0.809             0.876          0.718                     0.858 0.776          0.769      0.789

# Using provided seed concept, Joel's exact prompt, o3, setting excluded to None, same concept JSON, filtering by string, dropping concept class filter, take 2:
# [1] 0.7976214
# id      tps   fps   tns   fns fpsConservative tpsWeighted fpsWeighted tnsWeighted fnsWeighted fpsConservativeWeighted precision recall precisionConservative precisionWeighted recallWeighted precisionConservativeWeighted    f1 f1Conservative f1Weighted
# C01      42     2    55     9               2       111.          0          99.4        14.4                     0       0.955  0.824                 0.955             1              0.885                         1     0.884          0.884      0.939
# C02     196     1     5     8               3       458.          0           0          10.4                     0       0.995  0.961                 0.985             1              0.978                         1     0.978          0.973      0.989
# C03      27     0     0     7               0        74.4         0           0          35.7                     0       1      0.794                 1                 1              0.676                         1     0.885          0.885      0.806
# C04      56   108    36     7             157       141.        183.         63.3        35.5                   248.      0.341  0.889                 0.263             0.435          0.799                         0.362 0.493          0.406      0.563
# C06      83     0   114   116               0       146.          0         173.        178.                      0       1      0.417                 1                 1              0.452                         1     0.589          0.589      0.622
# C07      21     8     9    13               8        67.1        10.2        16.5        40.7                    10.2     0.724  0.618                 0.724             0.868          0.622                         0.868 0.667          0.667      0.725
# Total   425   119   219   160             170       997.        193.        353.        315.                    193.      0.836  0.750                 0.821             0.884          0.735                         0.872 0.791          0.784      0.803

# Code and prompt cleanup:
# [1] 0.8104825

# V1 prompts:
# [1] 0.805273
# id      tps   fps   tns   fns fpsConservative tpsWeighted fpsWeighted tnsWeighted fnsWeighted fpsConservativeWeighted precision recall precisionConservative precisionWeighted recallWeighted precisionConservativeWeighted    f1 f1Conservative f1Weighted
# C01      42     4    53     9               5       111.          0         99.4         14.4                     0       0.913  0.824                 0.894             1              0.885                         1     0.866          0.857      0.939
# C02     196     1     5     8               3       458.          0          0           10.4                     0       0.995  0.961                 0.985             1              0.978                         1     0.978          0.973      0.989
# C03      27     0     0     7               0        81.7         0          0           28.4                     0       1      0.794                 1                 1              0.742                         1     0.885          0.885      0.852
# C04      51    41   103    12              51       119.         49.4      197.          57.3                    62.1     0.554  0.810                 0.5               0.707          0.675                         0.657 0.658          0.618      0.690
# C06      80     0   114   119               0       146.          0        173.         178.                      0       1      0.402                 1                 1              0.450                         1     0.573          0.573      0.621
# C07      22    10     7    12              10        67.1        19.7        7.03        40.7                    19.7     0.688  0.647                 0.688             0.773          0.622                         0.773 0.667          0.667      0.690
# Total   418    56   282   167              69       982.         69.1      477.         329.                     69.1     0.858  0.740                 0.844             0.913          0.725                         0.905 0.794          0.788      0.809


