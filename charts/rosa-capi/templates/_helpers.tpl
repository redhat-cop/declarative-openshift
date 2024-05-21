{{/*
Expand the name of the chart.
*/}}
{{- define "rosa-capi.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "rosa-capi.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "rosa-capi.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rosa-capi.labels" -}}
helm.sh/chart: {{ include "rosa-capi.chart" . }}
{{ include "rosa-capi.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
rosa-capi/clusterName: {{ include "rosa-capi.name" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rosa-capi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rosa-capi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "rosa-capi.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "rosa-capi.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Add validations
*/}}
{{- define "validate.rosaControlPlane" -}}
{{- $errors := list -}}
{{- range $key, $machinePool := .Values.rosaControlPlane.machinePools }}
  {{- if $machinePool.name }}
    {{- if not (regexMatch "^[a-z0-9-]+$" $machinePool.name) }}
      {{- $errors = append $errors (printf "MachinePool Name \"%s\" must consist of lowercase alphanumeric characters." $machinePool.name) }}
    {{- end }}
    {{- if gt (len $machinePool.name) 15 }}
      {{- $errors = append $errors (printf "MachinePool Name \"%s\" must not exceed 15 characters in length." $machinePool.name) }}
    {{- end }}
  {{- end }}
  {{- $hasAutoscaling := or (and $machinePool.autoscaling $machinePool.autoscaling.minReplicas) (and $machinePool.autoscaling $machinePool.autoscaling.maxReplicas) -}}
  {{- if and $hasAutoscaling $machinePool.replicas }}
    {{- $errors = append $errors (printf "Autoscaling and Replicas are mutually exclusive. Error in MachinePool %s" $machinePool.name) -}}
  {{- end }}
  {{- if and (not $machinePool.replicas) (not $hasAutoscaling) }}
    {{- $errors = append $errors (printf "Either Replicas or Autoscaling must be configured in MachinePool %s" $machinePool.name) -}}
  {{- end }}
{{- end }}

{{- if $errors }}
  {{- fail (printf "Validation failed with the following errors:\n%s" (join "\n" $errors)) }}
{{- end }}
{{- end }} 