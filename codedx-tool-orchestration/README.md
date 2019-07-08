
# Code Dx Tool Orchestration

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Notes

- Argo controller service account name is not based on release name, so multiple installs of argo to the same namespace will cause conflicts unless `argo.controller.serviceAccount` is assigned to a new value.