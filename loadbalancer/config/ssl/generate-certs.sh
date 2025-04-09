#!/bin/bash

# 에러 처리 추가
set -euo pipefail
trap 'echo "Error on line $LINENO"' ERR

# 환경 변수 검증
if [ -z "${CERT_PATH:-}" ]; then
    CERT_PATH="/data/certs"
fi

COMBINED_PATH="$CERT_PATH/combined"

# 디렉토리 생성
mkdir -p $CERT_PATH $COMBINED_PATH

# 도메인 목록
DOMAINS=(
    "haproxy.local"
    "gitlab.local"
    "jenkins.local"
    "harbor.local"
    "grafana.local"
    "prometheus.local"
    "sonarqube.local"
    "security.local"
    "next-demo.local"
    "nest-demo.local"
    "python-demo.local"
)

# Root CA 생성
if [ ! -f "$CERT_PATH/rootCA.key" ]; then
    openssl genrsa -out $CERT_PATH/rootCA.key 4096
    openssl req -x509 -new -nodes -key $CERT_PATH/rootCA.key -sha256 -days 3650 \
        -out $CERT_PATH/rootCA.crt \
        -subj "/C=KR/ST=Seoul/L=Seoul/O=Local Development/CN=Local Root CA"
fi

# 인증서 유효성 검사 함수 추가
validate_cert() {
    local domain=$1
    echo "Validating certificate for $domain"
    openssl verify -CAfile $CERT_PATH/rootCA.crt $CERT_PATH/$domain.crt
}

# 백업 함수 추가
backup_certs() {
    local backup_dir="/data/certs/backup/$(date +%Y%m%d)"
    mkdir -p $backup_dir
    cp $CERT_PATH/*.{key,crt,pem} $backup_dir/ 2>/dev/null || true
}

# 기존 인증서 백업
backup_certs

# 각 도메인별 인증서 생성
for domain in "${DOMAINS[@]}"; do
    echo "Generating certificate for $domain"
    
    # CSR 설정 파일 생성
    cat > $CERT_PATH/$domain.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = KR
ST = Seoul
L = Seoul
O = Local Development
CN = $domain

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
EOF

    # 키 생성
    if [ ! -f "$CERT_PATH/$domain.key" ]; then
        openssl genrsa -out $CERT_PATH/$domain.key 2048
    fi

    # CSR 생성
    openssl req -new -key $CERT_PATH/$domain.key \
        -config $CERT_PATH/$domain.conf \
        -out $CERT_PATH/$domain.csr

    # 인증서 서명
    openssl x509 -req -in $CERT_PATH/$domain.csr \
        -CA $CERT_PATH/rootCA.crt \
        -CAkey $CERT_PATH/rootCA.key \
        -CAcreateserial \
        -out $CERT_PATH/$domain.crt \
        -days 365 \
        -sha256 \
        -extensions v3_req \
        -extfile $CERT_PATH/$domain.conf

    # HAProxy 형식으로 병합 (인증서 + 키 + Root CA)
    cat $CERT_PATH/$domain.crt $CERT_PATH/rootCA.crt $CERT_PATH/$domain.key > $COMBINED_PATH/$domain.pem
    
    echo "Certificate generated for $domain"
done

# HAProxy 메인 인증서 생성
cat $COMBINED_PATH/*.pem > $COMBINED_PATH/haproxy.pem

# 인증서 검증
for domain in "${DOMAINS[@]}"; do
    validate_cert $domain
done

# 권한 설정
chown -R root:root $CERT_PATH
chmod 644 $CERT_PATH/*.key $COMBINED_PATH/*.pem
chmod 644 $CERT_PATH/*.crt $CERT_PATH/*.conf
chmod 755 $CERT_PATH $COMBINED_PATH

# 권한 강화
find $CERT_PATH -type f -name "*.key" -exec chmod 644 {} \;
find $CERT_PATH -type f -name "*.pem" -exec chmod 644 {} \;
find $CERT_PATH -type f -name "*.crt" -exec chmod 644 {} \;

echo "All certificates have been generated successfully in $COMBINED_PATH"

# 인증서 저장 디렉토리
CERT_DIR="/data/certs/combined"

# 기본 설정값
DAYS=365
COUNTRY="KR"
STATE="Seoul"
LOCALITY="Seoul"
ORGANIZATION="DevOps"
ORGANIZATIONAL_UNIT="DevOps Team"
COMMON_NAME="haproxy.local"
EMAIL="admin@haproxy.local"

# HAProxy 메인 인증서 생성
openssl req -x509 -nodes -days $DAYS -newkey rsa:2048 \
    -keyout "$CERT_DIR/haproxy.key" \
    -out "$CERT_DIR/haproxy.crt" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

# Stats 페이지용 인증서 생성
openssl req -x509 -nodes -days $DAYS -newkey rsa:2048 \
    -keyout "$CERT_DIR/haproxy.local.key" \
    -out "$CERT_DIR/haproxy.local.crt" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

# HAProxy 형식으로 인증서 결합
cat "$CERT_DIR/haproxy.crt" "$CERT_DIR/haproxy.key" > "$CERT_DIR/haproxy.pem"
cat "$CERT_DIR/haproxy.local.crt" "$CERT_DIR/haproxy.local.key" > "$CERT_DIR/haproxy.local.pem"

# 권한 설정
chmod 644 "$CERT_DIR"/*.pem
chmod 644 "$CERT_DIR"/*.crt
chmod 644 "$CERT_DIR"/*.key
