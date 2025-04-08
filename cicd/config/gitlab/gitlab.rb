# GitLab 기본 설정
external_url 'https://gitlab.local'
gitlab_rails['gitlab_shell_ssh_port'] = 2222
gitlab_rails['time_zone'] = 'Asia/Seoul'

# 이메일 설정 비활성화
gitlab_rails['gitlab_email_enabled'] = false

# 메모리 최적화 설정
gitlab_rails['env'] = {
    'MALLOC_ARENA_MAX' => '2'
}

# 시스템 리소스 제한 설정
gitlab_rails['worker_processes'] = 2
unicorn['worker_processes'] = 2
postgresql['max_worker_processes'] = 4

# SMTP 설정이 필요한 경우 추가
# gitlab_rails['smtp_enable'] = true
# gitlab_rails['smtp_address'] = "smtp.gmail.com"
