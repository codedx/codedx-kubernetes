{{/* vim: set filetype=mustache: */}}

{{/*
Common name sanitization.
*/}}
{{- define "sanitize" -}}
{{- . | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "codedx-tool-orchestration.name" -}}
{{- include "sanitize" (default .Chart.Name .Values.nameOverride) -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "codedx-tool-orchestration.chart" -}}
{{- include "sanitize" (printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_") -}}
{{- end -}}

{{/*
Reuse common labels in resource for this chart.
*/}}
{{- define "codedx-tool-orchestration.commonLabels" -}}
chart: {{ include "codedx-tool-orchestration.chart" . }}
app: {{ include "codedx-tool-orchestration.name" . }}
release: {{ .Release.Name | quote }}
managed-by: {{ .Release.Service | quote }}
part-of: codedx-tool-orchestration
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codedx-tool-orchestration.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- include "sanitize" .Values.fullnameOverride }}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if eq $name .Release.Name -}}
{{- include "sanitize" .Release.Name -}}
{{- else -}}
{{- include "sanitize" (printf "%s-%s" .Release.Name $name) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "codedx-tool-orchestration.rbac.psp.tws.name" -}}
{{- $fullName := default (printf "%s-%s" (include "codedx-tool-orchestration.fullname" .) "tws-psp") .Values.podSecurityPolicy.tws.name -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx-tool-orchestration.rbac.psp.tws-workflows.name" -}}
{{- $fullName := default (printf "%s-%s" (include "codedx-tool-orchestration.fullname" .) "workflow-psp") .Values.podSecurityPolicy.twsWorkflows.name -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx-tool-orchestration.rbac.psp.argo.name" -}}
{{- $fullName := default (printf "%s-%s" (include "codedx-tool-orchestration.fullname" .) "argo-psp") .Values.podSecurityPolicy.argo.name -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx-tool-orchestration.rbac.psp.minio.name" -}}
{{- $fullName := default (printf "%s-%s" (include "codedx-tool-orchestration.fullname" .) "minio-psp") .Values.podSecurityPolicy.minio.name -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx-tool-orchestration.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "codedx-tool-orchestration.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "codedx-tool-orchestration.workflow.role.name" -}}
{{- (printf "%s-%s" (include "codedx-tool-orchestration.name" .) "workflow-role") -}}
{{- end -}}

{{- define "codedx-tool-orchestration.pre-delete-job" -}}
{{- include "sanitize" (printf "%s-pre-delete-job" (include "codedx-tool-orchestration.fullname" .)) -}}
{{- end -}}

{{- define "codedx-tool-orchestration.migrate-data-job" -}}
{{- include "sanitize" (printf "%s-migrate-data-job" (include "codedx-tool-orchestration.fullname" .)) -}}
{{- end -}}

{{- define "codedx-tool-orchestration.workflow.priorityClassName" -}}
{{- include "sanitize" (printf "%s-wf-pc" (include "codedx-tool-orchestration.fullname" .)) -}}
{{- end -}}

{{- define "codedx-tool-orchestration.service.priorityClassName" -}}
{{- include "sanitize" (printf "%s-svc-pc" (include "codedx-tool-orchestration.fullname" .)) -}}
{{- end -}}

{{- define "codedx-tool-orchestration.scc" -}}
{{- include "sanitize" (printf "%s-scc" (include "codedx-tool-orchestration.fullname" .)) -}}
{{- end -}}

{{- define "codedx-tool-orchestration.workflow-scc" -}}
{{- include "sanitize" (printf "%s-workflow-scc" (include "codedx-tool-orchestration.fullname" .)) -}}
{{- end -}}

{{- define "codedx-tool-orchestration.storageEndpoint" -}}
{{- if .Values.minio.enabled -}}
{{- print (include "minio.ref.fullname" .) "." .Release.Namespace ".svc.cluster.local:" .Values.minio.service.port | quote -}}
{{- else -}}
{{- .Values.workflowStorage.endpoint | quote -}}
{{- end -}}
{{- end -}}

{{- define "codedx-tool-orchestration.storageCredentialSecretName" -}}
{{- .Values.workflowStorage.existingSecret | default .Values.minio.global.minio.existingSecret | quote -}}
{{- end -}}

{{- define "codedx-tool-orchestration.storageTlsEnabled" -}}
{{- print (or .Values.workflowStorage.endpointSecure (and .Values.minio.enabled .Values.minio.tls.enabled)) -}}
{{- end -}}

{{- define "codedx-tool-orchestration.storageTlsConfigMapName" -}}
{{- .Values.workflowStorage.configMapName | default "" | quote -}}
{{- end -}}

{{- define "codedx-tool-orchestration.storageTlsConfigMapPublicCertName" -}}
{{- .Values.workflowStorage.configMapPublicCertKeyName | default "" | quote -}}
{{- end -}}

{{/*
Duplicates of a Minio template helper so we can reference Minio's service name
*/}}

{{- define "minio.ref.fullname" -}}
{{- if .Values.minio.fullnameOverride -}}
{{- .Values.minio.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "minio" .Values.minio.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "minio.ref.name" -}}
{{- default "minio" .Values.minio.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "minio.ref.serviceAccountName" -}}
{{- if .Values.minio.serviceAccount.create -}}
{{- default (include "minio.ref.fullname" .) .Values.minio.serviceAccount.name | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- default "default" .Values.minio.serviceAccount.name -}}
{{- end -}}
{{- end -}}