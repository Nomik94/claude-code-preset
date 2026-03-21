# 알림 정책 상세

## 에스컬레이션 정책

| 단계 | 조건 | 대상 | 채널 | 응답 시간 |
|------|------|------|------|----------|
| P1 (Critical) | 서비스 다운, 데이터 손실 | 온콜 엔지니어 | PagerDuty + 전화 | 5분 이내 |
| P2 (High) | 에러율 > 5%, 지연 > 3초 | 팀 리드 | Slack + PagerDuty | 15분 이내 |
| P3 (Medium) | 에러율 > 1%, 지연 > 1초 | 팀 채널 | Slack | 1시간 이내 |
| P4 (Low) | 경고성 지표 이상 | 팀 채널 | Slack (업무 시간) | 다음 업무일 |

## 알림 규칙 예시 (Datadog)

### 에러율 알림

```yaml
- name: "High Error Rate"
  type: metric alert
  query: "sum(last_5m):sum:http.request.count{status:5xx} / sum:http.request.count{*} > 0.01"
  message: |
    에러율이 1%를 초과했습니다.
    현재 에러율: {{value}}
    @slack-alerts @pagerduty-oncall
  thresholds:
    critical: 0.05
    warning: 0.01
  notify_no_data: true
  evaluation_delay: 60
```

### 응답시간 알림

```yaml
- name: "High Latency"
  type: metric alert
  query: "avg(last_5m):avg:http.request.duration.p95{*} > 1"
  message: |
    p95 응답시간이 1초를 초과했습니다.
    현재 p95: {{value}}s
    @slack-alerts
  thresholds:
    critical: 3
    warning: 1
```

### 서버 리소스 알림

```yaml
- name: "High CPU Usage"
  type: metric alert
  query: "avg(last_5m):avg:system.cpu.user{*} > 80"
  message: |
    CPU 사용률이 80%를 초과했습니다 (5분 평균).
    현재: {{value}}%
    @slack-infra
  thresholds:
    critical: 90
    warning: 80

- name: "High Memory Usage"
  type: metric alert
  query: "avg(last_5m):avg:system.mem.pct_usable{*} < 15"
  message: |
    가용 메모리가 15% 미만입니다.
    @slack-infra @pagerduty-oncall
  thresholds:
    critical: 10
    warning: 15

- name: "High Disk Usage"
  type: metric alert
  query: "avg(last_5m):avg:system.disk.in_use{*} > 85"
  message: |
    디스크 사용량이 85%를 초과했습니다.
    @slack-infra @pagerduty-oncall
  thresholds:
    critical: 90
    warning: 85
```

### DB 커넥션 풀 알림

```yaml
- name: "DB Connection Pool Exhaustion"
  type: metric alert
  query: "avg(last_5m):avg:postgresql.connections.active{*} / avg:postgresql.connections.max{*} > 0.8"
  message: |
    DB 커넥션 풀 사용률이 80%를 초과했습니다.
    @slack-infra
  thresholds:
    critical: 0.9
    warning: 0.8
```

### Health Check 알림

```yaml
- name: "Health Check Failed"
  type: http check
  url: "https://api.example.com/health"
  method: GET
  timeout: 10
  message: |
    Health check가 실패했습니다!
    @pagerduty-oncall @slack-critical
  thresholds:
    critical: 2  # 2회 연속 실패 시
```

## 알림 Best Practices

### 알림 피로 방지

1. **묶음 알림**: 같은 서비스의 관련 알림은 그룹화
2. **대기 시간**: 일시적 스파이크에 반응하지 않도록 5분 이상 지속 조건
3. **자동 해제**: 상태 복구 시 자동 해제 알림
4. **영업시간 설정**: P4는 업무 시간에만 발송

### 알림 메시지 포함 항목

- 무엇이 문제인지 (what)
- 현재 수치 (how bad)
- 대시보드 링크 (where to look)
- Runbook 링크 (how to fix)
- 에스컬레이션 경로 (who to call)

### 알림 채널 매핑

| 심각도 | Slack | PagerDuty | Email | 전화 |
|--------|-------|-----------|-------|------|
| P1 | #critical | O | O | O |
| P2 | #alerts | O | O | - |
| P3 | #alerts | - | - | - |
| P4 | #monitoring | - | - | - |
