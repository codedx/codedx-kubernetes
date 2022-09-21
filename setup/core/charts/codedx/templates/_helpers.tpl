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
{{- define "codedx.name" -}}
{{- include "sanitize" (default .Chart.Name .Values.nameOverride) -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "codedx.chart" -}}
{{- include "sanitize" (printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_") -}}
{{- end -}}

{{/*
Reuse common labels in resource for this chart.
*/}}
{{- define "codedx.commonLabels" -}}
chart: {{ include "codedx.chart" . }}
app: {{ include "codedx.name" . }}
release: {{ .Release.Name }}
managed-by: {{ .Release.Service }}
part-of: codedx
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codedx.fullname" -}}
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

{{/*
Determine the name of the volume to create and/or use for Code Dx's "appdata" storage.
*/}}
{{- define "volume.fullname" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- include "sanitize" (printf "%s-%s" .Release.Name "appdata") -}}
{{- end -}}
{{- end -}}

{{/*
Determine the name of the initContainer for Code Dx, which checks for MariaDB connectivity.
*/}}
{{- define "dbinit.fullname" -}}
{{- include "sanitize" (printf "%s-%s" .Release.Name "dbinit") -}}
{{- end -}}

{{/*
Determine the name of the Code Dx service.
*/}}
{{- define "codedx.servicename" -}}
{{ include "codedx.fullname" . }}
{{- end -}}

{{/*
Determine the type of service when exposing Code Dx based on the user-specified type and whether Ingress
is enabled.
*/}}
{{- define "codedx.servicetype" -}}
{{- if .Values.service.type -}}
{{- .Values.service.type -}}
{{- else }}
{{- if .Values.ingress.enabled -}}
{{- "ClusterIP" }}
{{- else -}}
{{- "LoadBalancer" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Determine the URL of the Code Dx service.
*/}}
{{- define "codedx.serviceurl" -}}
{{- $protocol := "http" }}
{{- if .Values.codedxTls.componentEnabled -}}
{{- $protocol = "https" -}}
{{- end -}}
{{- $port := .Values.codedxTomcatPort -}}
{{- if .Values.codedxTls.serviceEnabled -}}
{{- $port = .Values.codedxTlsTomcatPort -}}
{{- end -}}
{{- $protocol -}}://{{- include "codedx.servicename" . -}}:{{- $port -}}/codedx
{{- end -}}

{{/*
Determine the name of the configmap to create and/or use for holding the regular `codedx.props` and `setenv.sh` file.
*/}}
{{- define "codedx.props.configMapName" -}}
{{- include "sanitize" (printf "%s-configmap" (include "codedx.fullname" .)) -}}
{{- end -}}

{{/*
Determine the name of the configmap to use for the `logback.xml` file.
*/}}
{{- define "codedx.props.loggingConfigMapName" -}}
    {{- if .Values.loggingConfigMap -}}
        {{- .Values.loggingConfigMap -}}
    {{- else -}}
        {{- include "codedx.props.configMapName" . -}}
    {{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for Code Dx.
*/}}
{{- define "codedx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "codedx.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create NetworkPolicy port ranges for DNS resolution.
*/}}
{{- define "netpolicy.dns.ports" -}}
# DNS resolution
- port: 53
  protocol: UDP
- port: 53
  protocol: TCP
{{- end -}}

{{/*
Create NetworkPolicy port ranges.
*/}}
{{- define "netpolicy.ports" -}}
{{- $portData := . -}}
{{- if $portData.ports -}}
{{- if gt (len $portData.ports) 0 -}}
- ports:
{{- range $portData.ports }}
  - port: {{ . }}
    protocol: {{ $portData.protocol }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create NetworkPolicy TCP port ranges.
*/}}
{{- define "netpolicy.egress.ports.tcp" -}}
{{- $portData := dict "ports" .Values.networkPolicy.codedx.egress.extraPorts.tcp "protocol" "TCP" -}}
{{- include "netpolicy.ports" $portData -}}
{{- end -}}

{{/*
Create NetworkPolicy UDP port ranges.
*/}}
{{- define "netpolicy.egress.ports.udp" -}}
{{- $portData := dict "ports" .Values.networkPolicy.codedx.egress.extraPorts.udp "protocol" "UDP" -}}
{{- include "netpolicy.ports" $portData -}}
{{- end -}}

{{/*
Create a full Egress object for enabling DNS resolution in a NetworkPolicy.
*/}}
{{- define "netpolicy.dns.egress" -}}
egress:
- ports:
  {{- include "netpolicy.dns.ports" . | nindent 2 }}
{{- end -}}

{{/*
Create the name of the `props` file containing MariaDB credentials, which will be mounted for Code Dx.
*/}}
{{- define "codedx.mariadb.props.name" -}}
codedx.mariadb.props
{{- end -}}

{{/*
Create the full path to where the MariaDB `props` file will be mounted to within Code Dx.
*/}}
{{- define "codedx.mariadb.props.path" -}}
/opt/codedx/{{ include "codedx.mariadb.props.name" . }}
{{- end -}}

{{- define "codedx.props.ml.params" -}}
{{- printf " -Dcodedx.additional-props-ml=/opt/codedx/codedx-ml.props" -}}
{{- end -}}

{{- define "codedx.props.saml.params" -}}
{{- if and .Values.authentication.saml.samlIdpXmlFileConfigMap .Values.authentication.saml.samlSecret -}}
{{- printf " -Dcodedx.additional-props-saml=\"/opt/codedx/codedx-saml.props\" -Dcodedx.additional-props-saml-keystore=\"/opt/codedx/codedx-saml-keystore.props\"" -}}
{{- else -}}
{{ printf "" }}
{{- end -}}
{{- end -}}

{{/*
Create a one-line string of extra/optional parameters that will be passed to the Code Dx Tomcat image's `start.sh`, which will
be passed to the Code Dx installer and webapp. The parameters tell Code Dx to load config files from the given paths.
*/}}
{{- define "codedx.props.extra.params" -}}
{{- range .Values.codedxProps.extra -}}
{{- printf " -Dcodedx.additional-props-%s=\"/opt/codedx/%s\"" .key .key -}}
{{- end -}}
{{- range .Values.codedxProps.internalExtra -}}
{{- printf " -Dcodedx.additional-props-%s=\"/opt/codedx/%s\"" .key .key -}}
{{- end -}}
{{- include "codedx.props.ml.params" . -}}
{{- include "codedx.props.saml.params" . -}}
{{- end -}}

{{/*
Create a one-line string of all parameters to pass to Code Dx for loading additional `props` files.
*/}}
{{- define "codedx.props.params.combined" -}}
{{- printf "-Dcodedx.additional-props-mariadb=\"%s\"%s" (include "codedx.mariadb.props.path" .) (include "codedx.props.extra.params" .) -}}
{{- end -}}

{{/*
Create a separated YAML list of all parameters to pass to Code Dx for loading additional `props` files.
*/}}
{{- define "codedx.props.params.separated" -}}
- "-Dcodedx.additional-props-mariadb={{ include "codedx.mariadb.props.path" . }}"
-{{ include "codedx.props.ml.params" . }}
{{- range .Values.codedxProps.extra }}
- "-Dcodedx.additional-props-{{ .key }}=/opt/codedx/{{ .key }}"
{{- end -}}
{{- range .Values.codedxProps.internalExtra }}
- "-Dcodedx.additional-props-{{ .key }}=/opt/codedx/{{ .key }}"
{{- end -}}
{{- end -}}


{{/*
Determine the name to use to create and/or bind Code Dx's PodSecurityPolicy.
*/}}
{{- define "codedx.rbac.psp.name" -}}
{{- $fullName := default (printf "%s-%s" (include "codedx.fullname" .) "psp") .Values.podSecurityPolicy.codedx.name -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{/*
Determine the name to use to create and/or bind MariaDB's PodSecurityPolicy.
*/}}
{{- define "codedx.rbac.psp.dbname" -}}
{{- $fullName := default (printf "%s-%s" (include "codedx.fullname" .) "db-psp") .Values.podSecurityPolicy.mariadb.name -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.netpolicy.name" -}}
{{- $fullName := printf "%s-codedx-netpolicy" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.netpolicy.masterdb.name" -}}
{{- $fullName := printf "%s-mariadb-master-netpolicy" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.netpolicy.slavedb.name" -}}
{{- $fullName := printf "%s-mariadb-slave-netpolicy" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.serverXmlName" -}}
{{- $fullName := printf "%s-server-xml" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.priorityClassName" -}}
{{- $fullName := printf "%s-codedx-pc" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.scc" -}}
{{- $fullName := printf "%s-scc" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{/*
Duplicates of MariaDB template helpers so we can reference service/serviceAccount names
*/}}

{{- define "mariadb.ref.fullname" -}}
{{- if .Values.mariadb.fullnameOverride -}}
{{- .Values.mariadb.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "mariadb" .Values.mariadb.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.ref.secretName" -}}
{{- if .Values.mariadb.existingSecret -}}
{{ .Values.mariadb.existingSecret }}
{{- else -}}
{{ template "mariadb.ref.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.ref.serviceAccountName" -}}
{{- if .Values.mariadb.serviceAccount.create -}}
    {{ default (include "mariadb.ref.fullname" .) .Values.mariadb.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.mariadb.serviceAccount.name }}
{{- end -}}
{{- end -}}