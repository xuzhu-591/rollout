{{/*
podAnnotations:
*/}}
{{- define "podAnnotations" -}}
{{- if .Values.restartTime }}
github.com.horizoncd/user-restart-time: {{ .Values.restartTime }}
{{- end }}
{{- if .Values.git }}
{{- if .Values.git.url }}
horizoncd.github.io/git-url: {{ .Values.git.url }}
{{- end }}
{{- if .Values.git.branch }}
horizoncd.github.io/git-branch: {{ .Values.git.branch }}
{{- end }}
{{- if .Values.git.commitID }}
horizoncd.github.io/git-commit: {{ .Values.git.commitID }}
{{- end }}
{{- end }}
{{- end }}


{{/*
cpuRequest
*/}}
{{- define "cpuRequest" -}}
{{- $resource := .Values.app.spec.resource -}}
{{- $cpu := index (index (fromJson (tpl (.Values.resources | toJson) .)) $resource) "cpu" -}}
{{- if or (eq .Values.env.environment "online") (eq .Values.env.environment "pre") }}
  {{- if not (eq .Values.horizon.priority "P0") }}
    {{- $cpu = div (mul $cpu 10) .Values.oversale.cpu.online }}
  {{- end }}
{{- else }}
  {{- $cpu = div (mul $cpu 10) .Values.oversale.cpu.others }}
{{- end }}
{{- printf "%v" $cpu }}
{{- end }}

{{/*
cpuLimit
*/}}
{{- define "cpuLimit" -}}
{{- $resource := .Values.app.spec.resource -}}
{{- $cpu := index (index (fromJson (tpl (.Values.resources | toJson) .)) $resource) "cpu" -}}
{{- printf "%v" $cpu }}
{{- end }}


{{/*
memoryRequest
*/}}
{{- define "memoryRequest" -}}
{{- $resource := .Values.app.spec.resource -}}
{{- $memory := index (index (fromJson (tpl (.Values.resources | toJson) .)) $resource) "memory" -}}
{{- printf "%v" $memory }}
{{- end }}


{{/*
memoryLimit
*/}}
{{- define "memoryLimit" -}}
{{- $resource := .Values.app.spec.resource -}}
{{- $memory := index (index (fromJson (tpl (.Values.resources | toJson) .)) $resource) "memory" -}}
{{- printf "%v" $memory }}
{{- end }}

{{- define "resources" -}}
requests:
  ephemeral-storage: "10Mi"
  cpu: {{ include "cpuRequest" . }}m
  memory: {{ include "memoryLimit" . }}Mi
limits:
  ephemeral-storage: "1Gi"
  cpu: {{ include "cpuLimit" . }}m
  memory: {{ include "memoryLimit" . }}Mi
{{- end }}


{{- define "podLabels" -}}
horizoncd.github.io/application: {{ .Values.horizon.application }}
horizoncd.github.io/cluster: {{ .Values.horizon.cluster }}
horizoncd.github.io/environment: {{ .Values.env.environment }}
{{- end }}



{{- define "canarySteps" -}}

{{- if eq .Values.app.spec.autoscale "none" -}}
{{- if eq (int .Values.app.spec.replicas) 0 }}
  {{- printf "[]" -}}
{{- else }}
  {{- include "getCanarySteps" . }}
{{- end }}

{{- else }}

{{- if eq (int .Values.app.spec.minReplicas) 0 }}
  {{- printf "[]" -}}
{{- else }}
  {{- include "getCanarySteps" . }}
{{- end }}
{{- end }}
{{- end }}


{{- define "getCanarySteps" -}}
{{- $stepsTotal := 0 -}}
{{- if eq .Values.app.spec.autoscale "none" -}}
{{- $stepsTotal = int (min .Values.app.spec.replicas .Values.app.strategy.stepsTotal) -}}
{{- else }}
{{- $stepsTotal = int (min .Values.app.spec.minReplicas .Values.app.strategy.stepsTotal) -}}
{{- end }}
{{- $rate := div 100 $stepsTotal -}}
{{- if gt $stepsTotal 1 }}
  {{- $rate = div 100 (sub $stepsTotal 1) -}}
{{- end }}
{{- $pauseType := .Values.app.strategy.pauseType -}}
{{- $steps := "[" -}}
  {{- range $index := until $stepsTotal }}
    {{- $stepRate := mul $index $rate -}}
    {{- if eq (add $index 1) $stepsTotal -}}
      {{- $stepRate = "100" -}}
    {{- else if and (eq $index 0) (not (eq $stepsTotal 1)) -}}
      {{- $stepRate = "1" -}}
    {{- end -}}
    {{- $steps = cat $steps (printf "\"setWeight\": %v ," $stepRate) -}}
    {{- if and (eq $index 0) (not (eq $stepsTotal 1)) (not (eq $pauseType "none")) -}}
      {{- $steps = cat $steps "\"pause\": {}" "," }}
    {{- else if and (not (eq (add $index 1) $stepsTotal)) (eq $pauseType "all") -}}
      {{- $steps = cat $steps "\"pause\": {}" "," }}
    {{- end -}}
  {{- end -}}
{{- $steps = trimSuffix "," $steps -}}
{{- $steps = cat $steps "]" -}}
{{- printf "%v" $steps -}}
{{- end }}
