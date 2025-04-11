#!/bin/bash
set -e

# 신규 이미지 pull
docker pull $1

# 컨테이너 교체
docker-compose -f docker-compose.prod.yml up -d --no-deps --force-recreate app

# 이전 이미지 정리
docker image prune -f
