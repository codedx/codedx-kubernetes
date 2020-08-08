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
{{- $port := .Values.codedxTomcatPort -}}
{{- if .Values.codedxTls.enabled -}}
{{- $protocol = "https" -}}
{{- $port = .Values.codedxTlsTomcatPort -}}
{{- end -}}
{{- $protocol -}}://{{- include "codedx.servicename" . -}}:{{- $port -}}/codedx
{{- end -}}

{{/*
Check whether or not a Code Dx License has been defined in some way and can be mounted for use during
installation. The `default "" ...` ensures that unassigned values revert to an empty string, rather than
the placeholder text for an unassigned value which would be evaluated as "true" in the `or` statement.
*/}}
{{- define "codedx.license.exists" -}}
{{- or (default "" .Values.license.secret) (default "" .Values.license.file) -}}
{{- end -}}

{{/*
Determine the name of the secret to create and/or use for holding the Code Dx license.
*/}}
{{- define "codedx.license.secretName" -}}
{{- if .Values.license.secret -}}
{{- .Values.license.secret -}}
{{- else -}}
{{- include "sanitize" (printf "%s-license-secret" (include "codedx.fullname" .)) -}}
{{- end -}}
{{- end -}}

{{/*
Determine the name of the configmap to create and/or use for holding the regular `codedx.props` file,
`logback.xml` file, and `setenv.sh` file.
*/}}
{{- define "codedx.props.configMapName" -}}
{{- if .Values.codedxProps.configMap -}}
{{- .Values.codedxProps.configMap -}}
{{- else -}}
{{- include "sanitize" (printf "%s-configmap" (include "codedx.fullname" .)) -}}
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

{{/*
Determine the name of the secret to create and/or use for storing the `props` file containing MariaDB
credentials, which will be mounted for Code Dx.
*/}}
{{- define "codedx.mariadb.secretName" -}}
{{- $fullName := printf "%s-%s" .Release.Name "mariadb-secret" -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.props.ml.params" -}}
{{- printf " -Dcodedx.additional-props-ml=/opt/codedx/codedx-ml.props" -}}
{{- end -}}

{{- define "codedx.props.saml.params" -}}
{{- if .Values.authentication.saml.samlIdpXmlFile -}}
{{- printf " -Dcodedx.additional-props-saml=\"/opt/codedx/codedx-saml.props\"" -}}
{{- else -}}
{{ printf "" }}
{{- end -}}
{{- end -}}

{{- define "codedx.saml.keystore.pwd" -}}
    {{- $existingSecret := required "you must use .Values.existingSecret to specify the keystore password" .Values.existingSecret }}
    {{- /* Note: lookup function does not support --dry-run */ -}}
    {{- $data := (lookup "v1" "Secret" .Release.Namespace $existingSecret).data -}}
    {{- index $data "saml-keystore-password" | b64dec -}}
{{- end -}}

{{- define "codedx.saml.private.key.pwd" -}}
    {{- $existingSecret := required "you must use .Values.existingSecret to specify the private key password" .Values.existingSecret }}
    {{- /* Note: lookup function does not support --dry-run */ -}}
    {{- $data := (lookup "v1" "Secret" .Release.Namespace $existingSecret).data -}}
    {{- index $data "saml-private-key-password" | b64dec -}}
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

{{- define "codedx.cacerts.secretName" -}}
{{- $fullName := printf "%s-cacerts-secret" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.cacerts.pwd.secretName" -}}
{{- if .Values.existingSecret -}}
{{- .Values.existingSecret -}}
{{- else -}}
{{- $fullName := printf "%s-cacerts-pwd-secret" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}
{{- end -}}

{{- define "codedx.cacerts.pwd.secretKeyName" -}}
    {{- $keyName := "cacerts-password" }}
    {{- $existingSecret := .Values.existingSecret -}}
    {{- if $existingSecret -}}
        {{- /* Note: lookup function does not support --dry-run */ -}}
        {{- $data := (lookup "v1" "Secret" .Release.Namespace $existingSecret).data -}}
        {{- $val := index $data "cacerts-new-password" -}}
        {{- if $val -}}
            {{- $keyName = "cacerts-new-password" -}}
        {{- end -}}
    {{- end -}}
    {{- $keyName -}}
{{- end -}}

{{- define "codedx.adminSecretName" -}}
{{- if .Values.existingSecret -}}
{{- .Values.existingSecret -}}
{{- else -}}
{{- $fullName := printf "%s-admin-secret" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}
{{- end -}}

{{- define "codedx.serverXmlName" -}}
{{- $fullName := printf "%s-server-xml" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.priorityClassName" -}}
{{- $fullName := printf "%s-codedx-pc" (include "codedx.fullname" .) -}}
{{- include "sanitize" $fullName -}}
{{- end -}}

{{- define "codedx.mariadb.user" -}}
    {{- $existingSecret := .Values.existingSecret }}
    {{- if $existingSecret -}}
        {{- /* Note: lookup function does not support --dry-run */ -}}
        {{- $data := (lookup "v1" "Secret" .Release.Namespace $existingSecret).data -}}
        {{- $val := index $data "mariadb-codedx-username" -}}
        {{- if $val -}}
            {{- $val | b64dec -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{- define "codedx.mariadb.pwd" -}}
    {{- $existingSecret := .Values.existingSecret }}
    {{- if $existingSecret -}}
        {{- /* Note: lookup function does not support --dry-run */ -}}
        {{- $data := (lookup "v1" "Secret" .Release.Namespace $existingSecret).data -}}
        {{- $val := index $data "mariadb-codedx-password" -}}
        {{- if $val -}}
            {{- $val | b64dec -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{- define "codedx.mariadb.root.pwd" -}}
{{- $existingSecret := .Values.mariadb.existingSecret }}
{{- if $existingSecret -}}
{{- /* Note: lookup function does not support --dry-run */ -}}
{{- index (lookup "v1" "Secret" .Release.Namespace $existingSecret).data "mariadb-root-password" | b64dec -}}
{{- else -}}
{{- required "existing secret not found, so expected to find value for mariadb.rootUser.password" .Values.mariadb.rootUser.password -}}
{{- end -}}
{{- end -}}

{{- define "codedx.mariadb.replication.pwd" -}}
{{- $existingSecret := .Values.mariadb.existingSecret }}
{{- if $existingSecret -}}
{{- /* Note: lookup function does not support --dry-run */ -}}
{{- index (lookup "v1" "Secret" .Release.Namespace $existingSecret).data "mariadb-replication-password" | b64dec -}}
{{- else -}}
{{- required "existing secret not found, so expected to find value for mariadb.replication.password" .Values.mariadb.replication.password -}}
{{- end -}}
{{- end -}}

{{- define "codedx.mariadb.propsTemplate" -}}
# MariaDB creds stored in a secret
swa.db.user = 
{{- $user := include "codedx.mariadb.user" . -}}
{{- if $user -}}
{{- $user | quote -}}
{{- else -}}
{{- "root" | quote -}}
{{- end }}
swa.db.password =
{{- $pwd := include "codedx.mariadb.pwd" . -}}
{{- if $pwd -}}
{{- $pwd | quote -}}
{{- else -}}
{{- include "codedx.mariadb.root.pwd" . | quote -}}
{{- end }}
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