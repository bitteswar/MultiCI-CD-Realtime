{{/* templates/_helpers.tpl */}}

{{- define "sample-app.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "sample-app.fullname" -}}
{{- $name := include "sample-app.name" . -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- /* Return the ServiceAccount name: prefer .Values.serviceAccount.name, else fall back to "<release>-<chart>" */ -}}
{{- define "sample-app.serviceAccountName" -}}
{{- default (printf "%s-%s" .Release.Name .Chart.Name) .Values.serviceAccount.name -}}
{{- end -}}