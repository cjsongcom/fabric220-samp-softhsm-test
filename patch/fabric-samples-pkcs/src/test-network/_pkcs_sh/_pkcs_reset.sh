#!/bin/bash

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname ${SCRIPT}`
SCRIPTNAME=`basename ${SCRIPT}`

cd ${SCRIPTPATH}

. ../_pkcs.cfg

PKCS_IN_PATH=${_PKCS_CFG_PATH}/_pkcs_in
PKCS_DATA_PATH=${_PKCS_CFG_PATH}/_pkcs_data

if ! [ -d "${PKCS_IN_PATH}" ]; then
  echo "[ERR] can't find pkcs artifact path,${PKCS_IN_PATH}"
  exit 1
fi


#
# 이전 데이터 삭제
#

if [ -d "${PKCS_DATA_PATH}" ]; then
  # 도커 컨테이너가 root로 실행될경우 권한문제로 안지워지는 파일이 있을수 있음
  sudo rm -rf "${PKCS_DATA_PATH}"

  if [ $? -ne 0 ]; then
    echo "[ERR] failed to remove previous docker stuff,path=${PKCS_DATA_PATH}"
    exit 1
  fi
fi

mkdir -p "${PKCS_DATA_PATH}"

if [ $? -ne 0 ]; then
  echo "[ERR] can't make path, ${PKCS_DATA_PATH}"
  exit 1
fi


#
# 템플릿 복사
#

cp -rPa "${PKCS_IN_PATH}/"* "${PKCS_DATA_PATH}/"

if [ $? -ne 0 ]; then
  echo "[ERR] failed to copy artifact, src=${PKCS_IN_PATH}, dst=${PKCS_DATA_PATH}"
  exit 1
fi


#
#  softhsm 토큰 생성
#

# _pkcs.cfg 파일에 정의되어 있음
SHSM_TOKEN_PATH="${_PKCS_SHSM_TOKEN_PATH}"
SHSM_CONF_FILE_PATH="${_PKCS_SHSM_CONF_FILE_PATH}"

SHSM_SLOT=${_PKCS_SLOT}
SHSM_SO_PIN=${_PKCS_SO_PIN}
SHSM_PIN=${_PKCS_PIN}
SHSM_TOKEN=${_PKCS_TOKEN}
SHSM_LIB_PATH=${_PKCS_LIB_PATH}


# 토큰 폴더 생성

if [ -d "${SHSM_TOKEN_PATH}" ]; then
  echo "[INFO] delete previous token,path=${SHSM_TOKEN_PATH}"
  rm -rf "${SHSM_TOKEN_PATH}"

  if [ $? -ne 0 ]; then
    echo "[ERR] failed to delete previous token,path=${SHSM_TOKEN_PATH}"
    exit 1
  fi
fi


mkdir -p "${SHSM_TOKEN_PATH}"

echo -e "directories.tokendir=${SHSM_TOKEN_PATH} \
         \nobjectstore.backend=file \
         \nlog.level=ERROR \nslots.removable=false \nslots.mechanisms=ALL \
         \nlibrary.reset_on_fork=false\n" > "${SHSM_CONF_FILE_PATH}"

# softhsm 의 토큰 디렉토리 정보 수정
export SOFTHSM2_CONF="${SHSM_CONF_FILE_PATH}"

set -e
# 지정한 슬롯에 토큰 생성 및 SO-PIN(Security Officer 패스워드) 세팅
pkcs11-tool  --init-token --slot ${SHSM_SLOT} --label ${SHSM_TOKEN} \
                          --so-pin ${SHSM_PIN} --module "${SHSM_LIB_PATH}"

# 생성된 토큰에 PIN 세팅(사용자 패스워드)
pkcs11-tool --init-pin  --label ${SHSM_TOKEN} --so-pin ${SHSM_PIN} \
                        --login --pin ${SHSM_PIN} --module "${SHSM_LIB_PATH}"

pkcs11-tool --list-token-slots  --module "${SHSM_LIB_PATH}"

set +e

echo ""
echo "========================================================================="
echo " successfully created softhsm token"
echo "> token path=${SHSM_CONF_FILE_PATH}"
echo "========================================================================="
echo ""

#docker-compose -f ${_PKCS_FAB_SAMP_DK_COMPOSE_FILE_PATH} down
# docker rm -vf ca_orderer
# docker rm -vf ca_org1
# docker rm -vf ca_org2

# docker rm -vf peer0.org1.example.com
# docker rm -vf peer0.org2.example.com

# docker rm -vf orderer.example.com
# docker rm -vf couchdb
# docker rm -vf couchdb0
# docker rm -vf couchdb1
# docker rm -vf cli

sleep 1