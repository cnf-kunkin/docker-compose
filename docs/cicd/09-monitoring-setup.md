# 모니터링 설정 가이드

## 1. Prometheus 설정

### 1.1 기본 설정
/data/prometheus/prometheus.yml:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - '172.16.10.40:9100'  # Application VM
        - '172.16.10.10:9100'  # CI/CD VM
        - '172.16.10.11:9100'  # Harbor VM
        - '172.16.10.20:9100'  # Monitoring VM
        - '172.16.10.30:9100'  # Security VM

  - job_name: 'docker'
    static_configs:
      - targets:
        - '172.16.10.40:9323'  # Application VM Docker metrics

  - job_name: 'python-demo'
    metrics_path: '/metrics'
    scheme: 'https'
    basic_auth:
      username: 'prometheus'
      password: 'prometheus-password'
    static_configs:
      - targets: ['python-demo.local']

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins.local']

  - job_name: 'gitlab'
    metrics_path: '/-/metrics'
    static_configs:
      - targets: ['gitlab.local']

  - job_name: 'harbor'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['harbor.local:9090']
```

### 1.2 알림 규칙
/data/prometheus/rules/alerts.yml:
```yaml
groups:
  - name: application
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 1% ({{ $value }})"

      - alert: SlowResponseTime
        expr: rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow response times detected"
          description: "Average response time is above 500ms"

  - name: infrastructure
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is above 80%"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is above 85%"

      - alert: DiskSpaceRunningOut
        expr: 100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space running out"
          description: "Disk usage is above 85%"
```

## 2. Grafana 대시보드

### 2.1 데이터 소스 설정
1. Configuration > Data Sources > Add data source
2. Prometheus 선택:
   - Name: Prometheus
   - URL: http://prometheus:9090
   - Access: Server (default)
   - Scrape interval: 15s

### 2.2 대시보드 구성
1. Python Demo 애플리케이션 대시보드:
```json
{
  "dashboard": {
    "title": "Python Demo Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{status}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])",
            "legendFormat": "avg response time"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m])",
            "legendFormat": "error rate"
          }
        ]
      }
    ]
  }
}
```

2. 인프라스트럭처 대시보드:
```json
{
  "dashboard": {
    "title": "Infrastructure Overview",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Disk Usage",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)",
            "legendFormat": "{{instance}}"
          }
        ]
      }
    ]
  }
}
```

## 3. 로그 수집 (ELK Stack)

### 3.1 Filebeat 설정
/data/filebeat/filebeat.yml:
```yaml
filebeat.inputs:
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'

processors:
  - add_docker_metadata:
      host: "unix:///var/run/docker.sock"
  - decode_json_fields:
      fields: ["message"]
      target: "json"
      overwrite_keys: true

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  indices:
    - index: "python-demo-%{+yyyy.MM.dd}"
      when.contains:
        container.labels.com_docker_compose_service: "python-demo"

setup.kibana:
  host: "kibana:5601"

logging.json: true
```

### 3.2 Logstash 파이프라인
/data/logstash/pipeline/python-demo.conf:
```
input {
  beats {
    port => 5044
  }
}

filter {
  if [container][labels][com_docker_compose_service] == "python-demo" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:log_level} %{GREEDYDATA:message}" }
    }
    date {
      match => [ "timestamp", "ISO8601" ]
      target => "@timestamp"
    }
  }
}

output {
  if [container][labels][com_docker_compose_service] == "python-demo" {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "python-demo-%{+YYYY.MM.dd}"
    }
  }
}
```

## 4. 알림 설정

### 4.1 AlertManager 설정
/data/alertmanager/alertmanager.yml:
```yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  group_by: ['alertname', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - channel: '#monitoring'
    send_resolved: true
    title: |-
      [{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}
    text: >-
      {{ range .Alerts }}
      *Alert:* {{ .Annotations.summary }}
      *Description:* {{ .Annotations.description }}
      *Severity:* {{ .Labels.severity }}
      *Instance:* {{ .Labels.instance }}
      {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

### 4.2 이메일 알림 설정
/data/alertmanager/email-config.yml:
```yaml
global:
  smtp_smarthost: 'smtp.local:587'
  smtp_from: 'alertmanager@local'
  smtp_auth_username: 'alertmanager'
  smtp_auth_password: 'smtp-password'
  smtp_require_tls: true

receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'team@local'
    send_resolved: true
```

## 5. 성능 모니터링

### 5.1 Node Exporter 설정
각 서버의 /etc/systemd/system/node_exporter.service:
```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter \
    --collector.textfile.directory=/var/lib/node_exporter/textfile_collector \
    --collector.systemd \
    --collector.processes

[Install]
WantedBy=multi-user.target
```

### 5.2 cAdvisor 설정
docker-compose.yml에 추가:
```yaml
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "8080:8080"
    networks:
      - monitoring_network
```

## 6. 시각화

### 6.1 Grafana 알림 채널
1. Alerting > Notification channels
2. Slack 채널 추가:
   - Type: Slack
   - Webhook URL: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
   - Send reminders: 활성화

### 6.2 대시보드 공유
1. Share Dashboard:
   - 링크 생성
   - Snapshot 생성
   - Export to JSON

## 다음 단계
모니터링 설정이 완료되면, [통합 테스트](./10-integration-test.md) 가이드로 진행하세요.