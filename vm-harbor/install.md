<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# 프라이빗 네트워크에 Harbor 설치 및 사설 인증서 구성 가이드

Harbor는 엔터프라이즈급 프라이빗 Docker 레지스트리 서비스로, 조직 내부에서 Docker 이미지를 안전하게 저장하고 배포할 수 있는 솔루션입니다. 이 문서에서는 프라이빗 네트워크 환경에서 Harbor를 설치하고, 사설 인증서를 구성하는 방법, 그리고 정상 설치 여부를 테스트하는 방법을 상세히 안내합니다.

## Harbor 소개 및 필요성

Harbor는 프라이빗 Docker 레지스트리 서비스로, 회사나 개인용으로 수정된 Docker 이미지를 안전하게 관리할 수 있는 플랫폼입니다. 일반적으로 Docker는 공개 Docker Hub에서 이미지를 다운로드하지만, 이는 보안상 민감한 이미지를 저장하기에는 적합하지 않습니다. Harbor는 이러한 필요성에 맞춰 격리된 프라이빗 레지스트리 환경을 제공합니다[^1].

Harbor 설치를 위해서는 다음 두 가지 중요한 조건이 필요합니다:

1. 도메인 (없으면 인증서 발급이 어려움)
2. 인증서 (없으면 Docker 로그인 및 이미지 푸시 작업이 불가능)[^2]

## 사설 인증서 생성 방법

### 1. 디렉토리 준비

먼저 인증서 파일을 저장할 디렉토리를 생성합니다:

```bash
cd ~
mkdir -p ~/certs
cd ~/certs
```


### 2. CA(Certificate Authority) 인증서 생성

개인 CA 역할을 할 인증서를 생성합니다:

```bash
# CA 개인키(private key) 생성
openssl genrsa -out ca.key 4096

# AWS EC2 등에서 작업할 경우 .rnd 파일 생성 필요
cd /root
openssl rand -writerand .rnd

# CA 공개키(public key) 생성
openssl req -x509 -new -nodes -sha512 -days 3650 \
-subj "/C=KR/ST=Seoul/L=GangNam/O=YourOrg/OU=YourDept/CN=harbor.local" \
-key ca.key \
-out ca.crt
```

여기서 `-subj` 옵션의 값은 적절히 수정해야 합니다[^2].

### 3. 서버 인증서 생성

Harbor 서버용 인증서를 생성합니다:

```bash
# 서버 개인키 생성
openssl genrsa -out harbor.key 4096

# 서버 인증서 요청 파일 생성
openssl req -sha512 -new \
-subj "/C=KR/ST=Seoul/L=GangNam/O=YourOrg/OU=YourDept/CN=harbor.local" \
-key harbor.key \
-out harbor.csr
```


### 4. x509 v3 확장 파일 생성

x509 v3 확장 파일을 생성하여 서버 인증서에 추가 설정을 적용합니다:

```bash
cat &gt; v3.ext &lt;&lt;-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=harbor.local
DNS.2=www.harbor.local
EOF
```


### 5. 서버 인증서 최종 생성

확장 파일을 사용하여 최종 서버 인증서를 생성합니다:

```bash
openssl x509 -req -sha512 -days 3650 \
-extfile v3.ext \
-CA ca.crt -CAkey ca.key -CAcreateserial \
-in harbor.csr \
-out harbor.crt
```


### 6. 인증서 파일 복사

생성된 인증서를 Harbor와 Docker가 사용할 수 있도록 복사합니다:

```bash
# Harbor용 디렉토리 생성 및 인증서 복사
mkdir -p /data/cert
cp harbor.crt /data/cert/
cp harbor.key /data/cert/

# Docker용 인증서 디렉토리 생성 및 복사
mkdir -p /etc/docker/certs.d/harbor.local/
cp harbor.crt /etc/docker/certs.d/harbor.local/
cp harbor.key /etc/docker/certs.d/harbor.local/
cp ca.crt /etc/docker/certs.d/harbor.local/
```


## Harbor 설치 방법

Harbor 설치는 Docker 기반과 Kubernetes 기반의 두 가지 방식으로 진행할 수 있습니다.

### Docker 기반 설치 (Offline Installer 방식)

#### 1. Harbor 다운로드

Harbor 공식 GitHub에서 최신 버전의 offline installer를 다운로드합니다:

```bash
# 직접 다운로드가 가능한 경우
wget https://github.com/goharbor/harbor/releases/download/v2.6.0/harbor-offline-installer-v2.6.0.tgz

# SSL 지원이 안 되는 환경에서는 다른 PC에서 다운로드 후 파일 전송
# 또는 wget-ssl 패키지 설치 후 시도
```

참고: 시놀로지 DS1019+ 같은 환경에서는 wget이 SSL을 지원하지 않을 수 있으니, 일반 PC에서 다운로드 후 전송하거나 wget-ssl 패키지를 설치해야 합니다[^1].

#### 2. 압축 해제 및 설정 파일 준비

```bash
tar xvf harbor-offline-installer-v2.6.0.tgz
cd harbor

# 설정 파일 복사 및 수정
cp harbor.yml.tmpl harbor.yml
```

`harbor.yml` 파일을 열어 다음 항목을 수정합니다:

- hostname: Harbor 서버의 도메인 이름
- certificate 및 private_key: 앞서 생성한 인증서 경로 설정
- harbor_admin_password: 관리자 비밀번호 설정


#### 3. Harbor 설치 실행

```bash
sudo ./install.sh --with-notary --with-trivy
```


### Kubernetes 기반 설치 (Helm 사용)

#### 1. Helm 차트 준비

```bash
# Harbor Helm 리포지토리 추가
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```


#### 2. values.yaml 파일 생성 및 수정

harbor-values.yaml 파일을 생성하고 다음과 같이 구성합니다:

```yaml
harborAdminPassword: "YourAdminPassword"

service:
  type: ClusterIP
  
externalURL: https://harbor.local

ingress:
  enabled: true
  hostname: harbor.local
  annotations:
    kubernetes.io/ingress.class: nginx
  tls: true

persistence:
  enabled: true

tlsCertificate: |
  -----BEGIN CERTIFICATE-----
  (harbor.crt 내용 붙여넣기)
  -----END CERTIFICATE-----
  
tlsPrivateKey: |
  -----BEGIN PRIVATE KEY-----
  (harbor.key 내용 붙여넣기)
  -----END PRIVATE KEY-----
```


#### 3. Helm으로 Harbor 설치

```bash
# Harbor namespace 생성
kubectl create namespace harbor

# Harbor 설치
helm install harbor -f harbor-values.yaml bitnami/harbor -n harbor
```


#### 4. Harbor Core 문제 해결 (필요 시)

Harbor Core 파드가 `/etc/core/token` 디렉토리 관련 에러로 설치되지 않는 경우:

```bash
# 빈 ConfigMap 생성
kubectl apply -f - &lt;&lt;EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: harbor-core-token
  namespace: harbor
data:
  token: |
EOF

# Harbor Core 배포 수정
kubectl get deploy harbor-core -o yaml &gt; core.yaml
# core.yaml 파일 수정 후 적용
kubectl apply -f core.yaml
```

수정 내용:

```yaml
volumeMounts:
...
- mountPath: /etc/core/token
  name: core-token
  subPath: token
...
volumes:
...
- name: core-token
  configMap:
    name: harbor-core-token
```


## 정상 설치 테스트 방법

Harbor 설치 후 정상 작동 여부를 테스트하는 방법은 다음과 같습니다:

### 1. 웹 인터페이스 접속 테스트

웹 브라우저에서 설정한 도메인으로 접속해 봅니다:

```
https://harbor.local
```

로그인 화면이 나타나면 관리자 ID `admin`과 설정한 비밀번호를 입력합니다[^3].

### 2. Docker 로그인 테스트

터미널에서 Docker CLI를 사용하여 Harbor에 로그인합니다:

```bash
docker login harbor.local
```

Username과 Password를 입력하여 로그인이 성공하는지 확인합니다. 만약 인증서 문제로 로그인이 실패한다면, 인증서 설정을 다시 확인해야 합니다[^2].

### 3. 이미지 푸시/풀 테스트

간단한 테스트 이미지를 생성하고 Harbor에 푸시한 후 다시 풀하여 확인합니다:

```bash
# 테스트 이미지 준비
docker pull nginx:latest
docker tag nginx:latest harbor.local/library/nginx:v1

# Harbor에 이미지 푸시
docker push harbor.local/library/nginx:v1

# 이미지 삭제 후 다시 풀
docker rmi harbor.local/library/nginx:v1
docker pull harbor.local/library/nginx:v1
```

위 명령이 모두 성공하면 Harbor가 정상적으로 설치되었다고 볼 수 있습니다.

### 4. Kubernetes에서 테스트 (Kubernetes 환경인 경우)

Kubernetes에서 Harbor 레지스트리의 이미지를 사용하여 파드를 생성합니다:

```bash
# 테스트 파드 생성
kubectl create -f - &lt;&lt;EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-test
spec:
  containers:
  - name: nginx
    image: harbor.local/library/nginx:v1
EOF

# 파드 상태 확인
kubectl get pods
```

파드가 정상적으로 생성되면 Harbor에서 이미지를 성공적으로 가져왔다는 의미입니다[^3].

## 오프라인 환경에서의 설치

인터넷이 연결되지 않은 프라이빗 네트워크에서는 다음과 같은 과정을 통해 Harbor를 설치할 수 있습니다:

1. 인터넷이 연결된 환경에서 필요한 파일과 컨테이너 이미지를 다운로드합니다.
2. 다운로드한 파일과 이미지를 설치 대상 서버로 복사합니다.
3. 위의 설치 과정을 따라 Harbor를 설치합니다[^3].

## 결론

이 가이드를 통해 프라이빗 네트워크 환경에서 Harbor를 설치하고, 사설 인증서를 구성하는 방법, 그리고 정상 설치를 테스트하는 방법을 상세히 알아보았습니다. Harbor는 조직 내 Docker 이미지를 안전하게 관리할 수 있는 강력한 도구이며, 자체 인증서를 사용하여 보안을 강화할 수 있습니다.

설치 과정에서 문제가 발생하면 로그를 확인하고, 필요한 경우 재설치를 진행하세요. 특히 인증서 설정은 Harbor 사용에 있어 가장 중요한 부분이므로 주의 깊게 설정해야 합니다.

<div style="text-align: center">⁂</div>

[^1]: https://sonhc.tistory.com/975

[^2]: https://velog.io/@mirrorkyh/HARBOR-설치부터-쿠버네티스-연동.자체서명-도메인-有

[^3]: https://happycloud-lee.tistory.com/165

[^4]: https://velog.io/@gclee/Ubuntu에서-Harbor-설치-및-사용

[^5]: https://cbwstar.tistory.com/entry/쿠버네티스-Harbor하버-설치하기

[^6]: https://zunoxi.tistory.com/130

[^7]: https://mightytedkim.tistory.com/23

[^8]: https://sungbin-park.tistory.com/154

[^9]: https://velog.io/@comet1010/Harbor를-통한-Private-Repo-구축

[^10]: https://armyost.tistory.com/128

[^11]: https://babo-it.tistory.com/239

[^12]: https://akku-dev.tistory.com/69

[^13]: https://beer1.tistory.com/46

[^14]: https://beann.tistory.com/entry/NCRPrivate-URI를-활용한-Image-Push-1

[^15]: https://zunoxi.tistory.com/130

[^16]: https://engineering.linecorp.com/ko/blog/harbor-for-private-docker-registry/

[^17]: https://mokpolar.tistory.com/8

[^18]: https://post.naver.com/viewer/postView.naver?volumeNo=35878696\&memberNo=5733062

[^19]: https://kschoi728.tistory.com/66

[^20]: https://velog.io/@masterkorea01/Jenkins-Argocd-Gitlab

[^21]: https://lilo.tistory.com/120

[^22]: https://ksh-cloud.tistory.com/92

[^23]: https://blog.naver.com/kisukim94/223773991959

[^24]: https://my-grope-log.tistory.com/51

[^25]: https://somaz.tistory.com/336

