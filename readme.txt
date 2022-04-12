# OS : ubuntu 20.04.02 LTS / user: ubuntu
# fabric 2.2.0  : https://github.com/hyperledger/fabric.git
#
# fabric-samples 2.2.0
# > fabric/docs/source/install.rst
#   >> fabric v2.2.0
#   >> fabric-ca v2.0.0-alpha (1.4.7은 랜덤크래시 발생이슈로 사용하지않음)
# > golang 1.14.4
#  

1. ubuntu 20.04 iso로 설치후 apt update & upgrade 실행
2  docker(10.03-ce) & docker-compose(1.21.0) 설치
3. hosts 도메인 넣기
  > sudo bash -c "echo '127.0.0.1  ca.example.com ca.org1.example.com orderer.example.com peer0.org1.example.com' >> /etc/hosts"

# golang 및 기본디렉토리 생성
$ sudo mkdir -p /opt/gopath
$ sudo chown ubuntu:ubuntu /opt/gopath
$ mkdir -p /opt/gopath/src/github.com/hyperledger
$ cd /opt/gopath/src/github.com/hyperledger

1. pkcs11, softhsm 2.6.1, libp11 배포본 설치
3. golang 1.14.4  (for fabric 2.2.0)

# fabric-samples 2.2.0 설치 및 테스트
$ cd /opt/gopath/src/github.com/hyperledger
# 현재 디렉토리(/opt/gopath/src/github.com/hyperledger)에  
# > fabric-samples 2.2.0 다운로드 및 컨테이너 이미지 다운로드 된다
$ curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.2.0 2.0.0-alpha

# fabric-ca v2.0.0-alpha PKCS 컨테이너 이미지 생성
# fabric 2.2.0 에서 지정된 fabric-ca 버전 1.4.7을 사용할 경우
#  > fabric/docs/source/install.rst , line 54
#  > curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.2.0 1.4.7

# libltdl-dev 설치 필요
$ sudo apt install libltdl-dev

$ cd /opt/gopath/src/github.com/hyperledger
$ git clone -b v2.0.0-alpha https://github.com/hyperledger/fabric-ca.git
$ cd fabric-ca

# fabric-ca:2.0.0-alpah 컨테이너의 Base는 Alpine Linux v3.9.6

# fabric-ca 컨테이너 이미지 생성
$ make docker GO_TAGS=pkcs11

# 실제 만드는 부분은 fabric-ca/images/fabric-ca/Dockerfile 참고
# RUN go install -tags "${GO_TAGS}" -ldflags "${GO_LDFLAGS}" \
#        github.com/hyperledger/fabric-ca/cmd/fabric-ca-server \
#        && go install -tags "${GO_TAGS}" -ldflags "${GO_LDFLAGS}" \
#        github.com/hyperledger/fabric-ca/cmd/fabric-ca-client

# build fabric-ca-client,fabric-ca-server
# > fabric-ca/release/linux-amd64/bin/ 에 바이너리 생성됨
$ make release GO_TAGS=pkcs11 

# fabric 2.2.0 PKCS 컨테이너 이미지 생성
# fabric peer/orderer 컨테이너 베이스 이미지는 alpine-3.12.7 (fabric-ca-2.0-alpha는 alpine 3.9.6)
$ cd /opt/gopath/src/github.com/hyperledger
$ git clone -b v2.2.0 https://github.com/hyperledger/fabric.git

$ cd fabric

# docker image peer/orderer ..
$ make docker GO_TAGS=pkcs11

# build configtxgen, configtxlator, cryptogen, discover, idemixgen, orderer, peer
# > fabric/release/linux-amd64/bin/ 에 바이너리 생성됨
$ make release GO_TAGS=pkcs11 

# https://github.com/hyperledger/fabric/pull/1900
# > 'Allow BCCSP config to be set using environment variables'
# >> stephyee commented on 2 Oct 2020
#    @jyellick removed the overrides for hardcoded SW values
# >> fabric 1.4.1 peer 에서는 작동하던것이 2.x 에서는 BCCSP 관련 환경변수세팅이 작동하지않음
# 현재로서는 core.yaml/orderer.yaml 에 BCCSP 관련 사항 (PIN,TOKEN) 입력하여 사용
 
# fabric-samples 설치 및 테스트
1. fabric-samples 다운로드
  1.1  $ sudo mkdir -p "${GOPATH}/src/github.com/hyperledger"
  1.2  $ sudo chown -R ${USER}:${USER} "${GOPATH}/src"
  1.3  $ cd "${GOPATH}/src/github.com/hyperledger"
  1.4  $ git clone -b v1.4.1  https://github.com/hyperledger/fabric-samples.git
  1.5  $ cd fabric-samples

2. fabric-samples pkcs patch 설치
  2.1 $ cd ~/fabric220/patch/fabric-samples-pkcs
  2.2 $ install.sh
    2.2.1 # copy  configtxgen, cryptogen, fabric-ca-client, discover, 
            idemixgen, configtxlator to /usr/local/bin

3. fabric-samples fabcar test
  3.1 [공통] 예제에서 사용할 조직/관리자/사용자 Crypto SoftHSM에 생성 
    3.1.1  $ cd "${GOPATH}/src/github.com/hyperledger/fabric-samples/basic-network"
    3.1.2  $ ./generate.sh
  3.2 basic-network 예제 테스트 (채널 Join 까지 테스트)
    3.2.1  $ cd "${GOPATH}/src/github.com/hyperledger/fabric-samples/basic-network"
    3.2.2  $ ./start.sh
  3.3 fabcar 예제 테스트 ( invoke / query  까지 테스트)
    3.2.1  $ cd "${GOPATH}/src/github.com/hyperledger/fabric-samples/fabcar"
    3.2.2  $ ./startFabric.sh

#pkcs11 / softhsm 동작 테스트
1. pkcs11 (opensc 0.21.0) 테스트
  1.1 공통사항
    1.1.1  hsm 라이브러리 PATH: /usr/local/lib/softhsm/libsofthsm2.so
    1.1.2  토큰 저장 경로 : /var/lib/softhsm/tokens
          > 환경변수 SOFTHSM2_CONF="/etc/softhsm2.conf" 파일에 정의 되어있음
    1.1.3  토큰 이름 (--token) : ForFabric
    1.1.4  토큰 SO-PIN (--so-pin, Security Officer 패스워드) : 1234
    1.1.5  토큰 USER-PIN (--pin,  사용자 패스워드) : 98765432

  1.2 hsm 의 slot 0번에 신규 토큰(ForFabric) 생성 및 생성된 토큰에 SO-PIN(--so-pin) 지정
    $ pkcs11-tool  --init-token \
        --slot 0 \
        --label ForFabric \
        --so-pin 1234 \
        --module /usr/local/lib/softhsm/libsofthsm2.so 

    # 생성된 슬록/토큰 보기
    $ pkcs11-tool --list-token-slots \
        --module /usr/local/lib/softhsm/libsofthsm2.so 

  1.3 생성된 토큰(ForFabric)에 사용자 패스워드(--pin) 지정
    $ pkcs11-tool --init-pin \
        --label ForFabric \
        --so-pin 1234 \
        --login \
        --pin 98765432 \
        --module /usr/local/lib/softhsm/libsofthsm2.so 

  1.4 토큰(ForFabric) 에 EC Prime256v1(EC:prime256v1, EC:secp256r1) 키 생성
    $ pkcs11-tool --keypairgen \
        --login \
        --token-label ForFabric \
        --pin 98765432 \
        --label "<MY_KEY_NAME>" \
        --id `uuidgen | tr -d -` \
        --key-type EC:prime256v1 \
        --module /usr/local/lib/softhsm/libsofthsm2.so 

  1.5 토큰(ForFabric) 의 키 목록 보기
    $ pkcs11-tool --list-objects \
        --login \
        --token-label ForFabric \
        --pin 98765432 \
        --module /usr/local/lib/softhsm/libsofthsm2.so 

  1.6 토큰으로 개인키(privkey) , 인증서(cert), 공개키(pubkey) import
    $ openssl ecparam -name prime256v1 -genkey -out "ecc-private.key" 
    $ pkcs11-tool --write-object "ecc-private.key" \
        --login \
        --token-label ForFabric \
        --pin 98765432 \
        --type privkey \
        --label "<MY_KEY_NAME>" \
        --id `uuidgen | tr -d -` \
        --module /usr/local/lib/softhsm/libsofthsm2.so 

  1.7 토큰 삭제
    1.7.1 SoftHSM 의 경우 :  $ rm -rf /var/lib/token/*
    1.7.2 HSM 의 경우: HSM 제공업체 툴 사용


#
# 참고: 의존 패키지 소스 빌드
#

1. sudo apt install -y  build-essential libtool
2. softhsm 2.6.1 소스 빌드
  # ubuntu 20.04.2 LTS 기준 , openssl 1.1.1f
  $ sudo apt install -y  libssl-dev
  $ mkdir softhsm && cd softhsm
  $ wget https://github.com/opendnssec/SoftHSMv2/archive/refs/tags/2.6.1.tar.gz
  $ tar xvzfp 2.6.1.tar.gz
  $ cd SoftHSMv2-2.6.1
  $ ./autogen.sh
  $ ./configure
  $ make -j 8
  $ sudo make install

  # alpine 컨테이너에서 빌드
  $ apk add --update autoconf
  $ apk add --update libtool
  $ apk add --update make
  $ apk add --update g++
  $ apk add --update openssl-dev
  # 컨테이너외부에서 softhsm 2.6.1 복사
  $ docker cp softhsm-2.6.1  CONTAINER_ID:/tmp
  # 컨테이너 안에서 실행
  $ docker exec -it  CONTAINER_ID  sh
  $ cd /tmp
  $ configure --enable-shared=yes  --enable-static=yes
  $ make  -j 8 && make install

3. 필요 파일만 추출해서 배포파일 만들기
  $ cd softhsm
  $ mkdir bin lib etc
  $ cp /usr/local/bin/softhsm2*    ./bin/
  $ cp -r /usr/local/lib/softhsm   ./lib/
  $ cp /etc/softhsm2.conf          ./etc/
  $ tar cvzfp softhsm-install-u20.04.02-2.6.1.tar  bin lib etc
  # bin 과 lib 폴더의 내용을 tar 압축해서 배포서버의 /usr/local 에 tar 압축풀어서 배포

4. opensc 0.21.0 (pkcs11-lib) 소스 빌드
  $ sudo apt install -y  libpcsclite-dev 
  $ mkdir opensc && cd opensc
  $ wget https://github.com/OpenSC/OpenSC/releases/download/0.21.0/opensc-0.21.0.tar.gz 
  $ tar xvzfp opensc-0.21.0.tar.gz
  $ cd opensc-0.21.0
  $ ./configure
  $ make -j 8
  $ sudo make install
  # 필요 파일만 추출해서 배포파일 만들기
  $ cd opensc-0.21.0
  $ mkdir bin lib   
  $ cp /usr/local/bin/pkcs11-tool            ./bin
  $ cp /usr/local/lib/opensc-pkcs11.*        ./lib
  $ cp /usr/local/lib/libopensc.la           ./lib
  $ cp /usr/local/lib/libopensc.so.7.0.0     ./lib
  $ cp -P /usr/local/lib/libopensc.so.7      ./lib
  $ cp -P /usr/local/lib/libopensc.so        ./lib
  $ tar cvzfp opensc-install-u20.04.02-0.21.0.tar bin lib
  # bin 과 lib 폴더의 내용을 tar 압축해서 배포서버의 /usr/local 에 tar 압축풀어서 배포
