{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "codedx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codedx.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if eq $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "volume.fullname" -}}
{{- printf "%s-%s" .Release.Name "appdata" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dbinit.fullname" -}}
{{- printf "%s-%s" .Release.Name "dbinit" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "codedx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "codedx.servicetype" -}}
{{- if and (.Values.service) (default "" .Values.service.type) -}}
{{- .Values.service.type -}}
{{- else }}
{{- if .Values.ingress.enabled -}}
{{- "ClusterIP" }}
{{- else -}}
{{- "LoadBalancer" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "codedx.license.exists" -}}
{{- or (default "" .Values.codedx.license.secret) (default "" .Values.codedx.license.file) -}}
{{- end -}}

{{- define "codedx.license.secretName" -}}
{{- if .Values.codedx.license.secret -}}
{{- .Values.codedx.license.secret -}}
{{- else -}}
{{- printf "%s-license-secret" (include "codedx.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "codedx.props.configMapName" -}}
{{- if .Values.codedx.props.configMap -}}
{{- .Values.codedx.props.configMap -}}
{{- else -}}
{{- printf "%s-configmap" (include "codedx.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "codedx.serviceAccountName" -}}
{{- if .Values.rbac.codedx.serviceAccount.create -}}
{{ default (include "codedx.fullname" .) .Values.rbac.codedx.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.rbac.codedx.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Port ranges for DNS resolution
*/}}
{{- define "netpolicy.dns.ports" -}}
# DNS resolution
- port: 53
  protocol: UDP
- port: 53
  protocol: TCP
{{- end -}}

{{/*
Full Egress object for DNS resolution
*/}}
{{- define "netpolicy.dns.egress" -}}
egress:
- ports:
  {{- include "netpolicy.dns.ports" . | nindent 2 }}
{{- end -}}

{{- define "codedx.mariadb.props.name" -}}
codedx.mariadb.props
{{- end -}}
{{- define "codedx.mariadb.props.path" -}}
/opt/codedx/{{ include "codedx.mariadb.props.name" . }}
{{- end -}}

{{- define "codedx.mariadb.secretName" -}}
{{- default (printf "%s-%s" .Release.Name "mariadb-secret") .Values.codedx.props.mariadb.secretName -}}
{{- end -}}

{{- define "codedx.props.extra.params" -}}
{{- range .Values.codedx.props.extra -}}
{{- printf " -Dcodedx.additional-props-%s=\"/opt/codedx/%s\"" .key .key -}}
{{- end -}}
{{- end -}}

{{- define "codedx.props.params.combined" -}}
{{- printf "-Dcodedx.additional-props-mariadb=\"%s\"%s" (include "codedx.mariadb.props.path" .) (include "codedx.props.extra.params" .) -}}
{{- end -}}

{{- define "codedx.props.params.separated" -}}
- "-Dcodedx.additional-props-mariadb={{ include "codedx.mariadb.props.path" . }}"
{{- range .Values.codedx.props.extra }}
- "-Dcodedx.additional-props-{{ .key }}=/opt/codedx/{{ .key }}"
{{- end -}}
{{- end -}}

{{- define "codedx.rbac.psp.name" -}}
{{- default (printf "%s-%s" (include "codedx.fullname" .) "psp") .Values.rbac.codedx.podSecurityPolicy.name -}}
{{- end -}}

{{- define "codedx.rbac.db.psp.name" -}}
{{- default (printf "%s-%s" (include "codedx.fullname" .) "db-psp") .Values.rbac.db.podSecurityPolicy.name -}}
{{- end -}}

{{- define "mariadb.master.fullname" -}}
{{- if .Values.mariadb.replication.enabled -}}
{{- printf "%s-%s" .Release.Name "mariadb-master" | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "mariadb" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.slave.fullname" -}}
{{- printf "%s-%s" .Release.Name "mariadb-slave" | trunc 63 | trimSuffix "-" -}}
{{- end -}}