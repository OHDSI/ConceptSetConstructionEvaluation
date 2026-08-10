ConceptSetConstructionEvaluation
================================

[![Build Status](https://github.com/OHDSI/ConceptSetConstructionEvaluation/workflows/R-CMD-check/badge.svg)](https://github.com/OHDSI/ConceptSetConstructionEvaluation/actions?query=workflow%3AR-CMD-check)
[![codecov.io](https://codecov.io/github/OHDSI/ConceptSetConstructionEvaluation/coverage.svg?branch=main)](https://app.codecov.io/github/OHDSI/ConceptSetConstructionEvaluation?branch=mai)

Introduction
============

This R package provides function for evaluating automated concept set constructors.


Features
========
- Uses the gold standard established during the first OHDSI MindsMeetMachines challenge.


Examples
========

```r
data(ai3ConceptSets)
results <- evaluateConceptSets(ai3ConceptSets)
results$f1ConservativeWeighted[results$id == "Total"]
# [1] 0.8764369
```


Technology
============

ConceptSetConstructionEvaluation is an R package. The gold standard is stored as Microsoft Excel files.


System Requirements
===================

Running the package requires R.


Installation
============

1. See the instructions [here](https://ohdsi.github.io/Hades/rSetup.html) for configuring your R environment.

2. In R, use the following commands to download and install ConceptSetConstructionEvaluation:
    
    ```r
    install.packages("remotes")
    remotes::install_github("ohdsi/ConceptSetConstructionEvaluation")
    ```

User Documentation
==================
Documentation can be found on the [package website](https://ohdsi.github.io/ConceptSetConstructionEvaluation/).

PDF versions of the documentation are also available:

* Package manual: [DatabaseConnector manual](https://raw.githubusercontent.com/OHDSI/ConceptSetConstructionEvaluation/main/extras/ConceptSetConstructionEvaluation.pdf) 


Support
=======

* Developer questions/comments/feedback: <a href="http://forums.ohdsi.org/c/developers">OHDSI Forum</a>
* We use the <a href="https://github.com/OHDSI/ConceptSetConstructionEvaluation/issues">GitHub issue tracker</a> for all bugs/issues/enhancements


Contributing
============

Read [here](https://ohdsi.github.io/Hades/contribute.html) how you can contribute to this package.


License
=======

ConceptSetConstructionEvaluation is licensed under Apache License 2.0.


Development
===========

ConceptSetConstructionEvaluation is being developed in R Studio.


### Development status

Under development. Use at your own risk.

