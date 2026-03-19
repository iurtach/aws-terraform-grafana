global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'slack-notifications'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: '${slack_webhook_url}' 
        channel: '#monitoring-alerts'  
        send_resolved: true
        title: '{{ if eq .Status "firing" }}🔥 ALARM:{{ else }}✅ RESOLVED:{{ end }} {{ .CommonLabels.alertname }}'
        text: >-
          {{ range .Alerts }}
            *Alert:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
            *Severity:* `{{ .Labels.severity }}`
            *Instance:* {{ .Labels.instance }}
          {{ end }}