route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h
  receiver: 'telegram-notifications'

receivers:
- name: 'telegram-notifications'
  telegram_configs:
  - bot_token: '${bot_token}'
    chat_id: ${chat_id}
    parse_mode: 'HTML'
    message: |
      <b>🚨 Alert: {{ .Status | toUpper }}</b>
      <b>Name:</b> {{ .CommonLabels.alertname }}
      <b>Server:</b> {{ .CommonLabels.instance }}
      <b>Description:</b> {{ .CommonAnnotations.description }}