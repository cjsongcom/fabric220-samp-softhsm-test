#!/bin/bash

#==============================================================================
# peer organization : org1.example.com
#==============================================================================

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname ${SCRIPT}`
SCRIPTNAME=`basename ${SCRIPT}`

cd ${SCRIPTPATH}


#==============================================================================
# common
#==============================================================================

. ../_pkcs.cfg

# go 1.15 이상 SAN 오류 방지용
export GODEBUG=x509ignoreCN=0

export FABRIC_CA_CLIENT_HOME=
export FABRIC_LOGGING_SPEC=DEBUG


#===============================================================================
# 조직정보 정의
#===============================================================================

ORG_DOMAIN=org1.example.com
ORG_IS_ORDERER=0

ORG_TLS_ENABLE=0
ORG_FACS_PROTO=http
if [ "${ORG_TLS_ENABLE}" -eq 1 ]; then
  ORG_FACS_PROTO=https
fi
ORG_FACS_CRYPTO_WORK_PATH="${_PKCS_CFG_PATH}/_pkcs_data/crypto/${ORG_DOMAIN}"
ORG_FACS_CA_NAME="ca.${ORG_DOMAIN}"
ORG_FACS_ADDRESS="ca.${ORG_DOMAIN}:8054"
ORG_FACS_URL="${ORG_FACS_PROTO}://${ORG_FACS_ADDRESS}"
ORG_FACS_SU_ENROLL_URL="${ORG_FACS_PROTO}://admin:adminpw@${ORG_FACS_ADDRESS}"
ORG_FACS_SU_MSP="${ORG_FACS_CRYPTO_WORK_PATH}/ca-su/msp"
ORG_FCA_CLI_CFG_FILE_PATH=${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config/fabric-ca-client-config.yaml

ORG_PEER0_FQDN=peer0.${ORG_DOMAIN}
ORG_ADMIN_ID=Admin@${ORG_DOMAIN}
ORG_USER1_ID=User1@${ORG_DOMAIN}

# 상대경로를 사용할경우 fabric-ca-client -H 로 지정한 경로(FARBIC_CONFIG_PATH)를 시작디렉토리로 사용한다.
ORG_CRYPTO_BASE=${_PKCS_CFG_PATH}/crypto-config/peerOrganizations/${ORG_DOMAIN}

# org1.example.com/ca
ORG_CRYPTO_CA="${ORG_CRYPTO_BASE}/ca"
# org1.example.com/msp
ORG_CRYPTO_MSP="${ORG_CRYPTO_BASE}/msp"
# org1.example.com/peers
ORG_CRYPTO_NODES="${ORG_CRYPTO_BASE}/peers"
# org1.example.com/users
ORG_CRYPTO_USERS="${ORG_CRYPTO_BASE}/users"
# org1.example.com/users/Admin@org1.example.com
ORG_CRYPTO_ADMIN="${ORG_CRYPTO_USERS}/${ORG_ADMIN_ID}"
# org1.example.com/users/User1@org1.example.com
ORG_CRYPTO_USER1="${ORG_CRYPTO_USERS}/${ORG_USER1_ID}"
# org1.example.com/peers/peer0.org1.example.com
ORG_CRYPTO_PEER0="${ORG_CRYPTO_NODES}/${ORG_PEER0_FQDN}"


#===============================================================================
# fabric-ca-client 가 사용할 fabric-ca-client-config.yaml 에 HSM 정보 세팅
#===============================================================================

# org1.example.com
set -e
sed -i "s|        Library:.*|        Library: ${_PKCS_LIB_PATH}|g"  "${ORG_FCA_CLI_CFG_FILE_PATH}"
sed -i "s|        Pin:.*|        Pin: ${_PKCS_PIN}|g"                "${ORG_FCA_CLI_CFG_FILE_PATH}"
sed -i "s|        Label:.*|        Label: ${_PKCS_TOKEN}|g"      "${ORG_FCA_CLI_CFG_FILE_PATH}"
set +e


#===============================================================================
# exaxmple.com / org1.example.com 의 fabric-ca-server 에서 SuperUser MSP 가져오기
#===============================================================================

set -e
# fabric-ca-server(ca.org1.example.com) 에서 SuperUser MSP 가져오기
export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
fabric-ca-client enroll -u "${ORG_FACS_SU_ENROLL_URL}" \
  --caname "${ORG_FACS_CA_NAME}" \
  -H "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
  -M "${ORG_FACS_SU_MSP}" \
  2>&1
set +e


#===============================================================================
# fabric-ca-server(ca.org1.example.com) 에서 node, admin id/pw 등록
#===============================================================================

#
# admin/adminpw
#

fcas_check_user_id_exist "${ORG_FACS_URL}" \
  "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
  "${ORG_FACS_SU_MSP}" \
  "${ORG_ADMIN_ID}"

id_rst=$?

if [ ${id_rst} -eq 0 ]; then
  fabric-ca-client register -u "${ORG_FACS_URL}" \
    --caname "${ORG_FACS_CA_NAME}" \
    -H "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
    -M "${ORG_FACS_SU_MSP}" \
    --id.name ${ORG_ADMIN_ID} --id.secret peeradminpw --id.type admin

  if [ $? -ne 0 ]; then
    echo "[ERR] failed to register id: ${ORG_ADMIN_ID} "
    exit 1
  fi

elif [ ${id_rst} -eq 2 ]; then
  echo "[INFO] ${ORG_ADMIN_ID} is already registered, skip"
else 
  echo "[ERR] failed to register id: ${ORG_ADMIN_ID} "
fi


#
# user1/userpw
#

fcas_check_user_id_exist "${ORG_FACS_URL}" \
  "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
  "${ORG_FACS_SU_MSP}" \
  "${ORG_USER1_ID}"

id_rst=$?

if [ ${id_rst} -eq 0 ]; then
  fabric-ca-client register -u "${ORG_FACS_URL}" \
    --caname "${ORG_FACS_CA_NAME}" \
    -H "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
    -M "${ORG_FACS_SU_MSP}" \
    --id.name ${ORG_USER1_ID} --id.secret userpw --id.type client

  if [ $? -ne 0 ]; then
    echo "[ERR] failed to register id: ${ORG_USER1_ID} "
    exit 1
  fi

elif [ ${id_rst} -eq 2 ]; then
  echo "[INFO] ${ORG_USER1_ID} is already registered, skip"
else 
  echo "[ERR] failed to register id: ${ORG_USER1_ID} "
fi


#
# peer0.org1.example.com / peerpw
#

fcas_check_user_id_exist "${ORG_FACS_URL}" \
  "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
  "${ORG_FACS_SU_MSP}" \
  "${ORG_PEER0_FQDN}"

id_rst=$?

if [ ${id_rst} -eq 0 ]; then
  fabric-ca-client register -u "${ORG_FACS_URL}" \
    --caname "${ORG_FACS_CA_NAME}" \
    -H "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
    -M "${ORG_FACS_SU_MSP}" \
    --id.name "${ORG_PEER0_FQDN}" --id.secret peerpw  --id.type peer

  if [ $? -ne 0 ]; then
    echo "[ERR] failed to register id: peer0.org1.example.com "
    exit 1
  fi

elif [ ${id_rst} -eq 2 ]; then
  echo "[INFO] peer0.org1.example.com is already registered, skip"
else 
  echo "[ERR] failed to register id: peer0.org1.example.com "
fi


#============================================================================
# fabric-ca-server(ca.org1.example.com) 에서 node, admin msp 생성
#============================================================================


if [ -d "${ORG_CRYPTO_BASE}" ]; then
  rm -rf "${ORG_CRYPTO_BASE}"
fi

mkdir -p "${ORG_CRYPTO_BASE}"


#
# Admin@org1.example.com
#

if [ -d "${ORG_CRYPTO_ADMIN}" ]; then
  rm -rf "${ORG_CRYPTO_ADMIN}"
fi

# --loglevel=debug
fabric-ca-client enroll \
  -u "${ORG_FACS_PROTO}://${ORG_ADMIN_ID}:peeradminpw@${ORG_FACS_ADDRESS}" \
  --caname "${ORG_FACS_CA_NAME}" \
  -H "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
  -M "${ORG_CRYPTO_ADMIN}/msp/"

if [ $? -ne 0 ]; then
  echo "[ERR] failed to enroll msp, ${ORG_ADMIN_ID}"
  exit 1
fi


#
# User1@org1.example.com
#

if [ -d "${ORG_CRYPTO_USER1}" ]; then
  rm -rf "${ORG_CRYPTO_USER1}"
fi

fabric-ca-client enroll \
  -u "${ORG_FACS_PROTO}://${ORG_USER1_ID}:userpw@${ORG_FACS_ADDRESS}" \
  --caname "${ORG_FACS_CA_NAME}" \
  -H "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
  -M "${ORG_CRYPTO_USER1}/msp/"

if [ $? -ne 0 ]; then
  echo "[ERR] failed to enroll msp, ${ORG_USER1_ID}"
  exit 1
fi


#
# peer0.org1.example.com
#

if [ -d "${ORG_CRYPTO_PEER0}" ]; then
  rm -rf "${ORG_CRYPTO_PEER0}"
fi

# enroll url : http://peer0.org1.example.com:peerpw@127.0.0.1:7054
# ca-name : ca.org1.example.com
# rst) peer0.org1.example.com/msp/cacerts/127-0.0-1-7054-ca-org1-example-com.pem
fabric-ca-client enroll \
  -u "${ORG_FACS_PROTO}://${ORG_PEER0_FQDN}:peerpw@${ORG_FACS_ADDRESS}" \
  --caname "${ORG_FACS_CA_NAME}" \
  --csr.hosts "${ORG_PEER0_FQDN}" \
  -H "${ORG_FACS_CRYPTO_WORK_PATH}/fca_client_config" \
  -M "${ORG_CRYPTO_PEER0}/msp/"

if [ $? -ne 0 ]; then
  echo "[ERR] failed to enroll msp, ${ORG_PEER0_FQDN}"
  exit 1
fi


#============================================================================
# cryptogen 으로 msp 생성했을 떄처럼 인증서 이름/위치 경로를 변경
#============================================================================

set -e

#
# org1.example.com/ca
#

if [ -d "${ORG_CRYPTO_CA}" ]; then
  rm -rf "${ORG_CRYPTO_CA}"
fi

mkdir -p "${ORG_CRYPTO_CA}"

# admin/msp/cacerts/ 의 인증서를 ca 인증서로 사용
cp "${ORG_CRYPTO_USERS}/${ORG_ADMIN_ID}/msp/cacerts/"*  "${ORG_CRYPTO_CA}/${ORG_FACS_CA_NAME}-cert.pem"


#
# org1.example.com/msp
#

if [ -d "${ORG_CRYPTO_MSP}" ]; then
  rm -rf "${ORG_CRYPTO_MSP}"
fi

mkdir -p "${ORG_CRYPTO_MSP}/admincerts"
mkdir -p "${ORG_CRYPTO_MSP}/cacerts"
mkdir -p "${ORG_CRYPTO_MSP}/tlscacerts"

cp "${ORG_CRYPTO_USERS}/${ORG_ADMIN_ID}/msp/signcerts/"*    "${ORG_CRYPTO_MSP}/admincerts/${ORG_ADMIN_ID}-cert.pem"
cp "${ORG_CRYPTO_USERS}/${ORG_ADMIN_ID}/msp/cacerts/"*      "${ORG_CRYPTO_MSP}/cacerts/${ORG_FACS_CA_NAME}-cert.pem"


#
# org1.example.com/peers/peer0.org1.example.com
#

if [ "${ORG_IS_ORDERER}" == 0 ]; then

  mv "${ORG_CRYPTO_PEER0}/msp/cacerts/"*    "${ORG_CRYPTO_PEER0}/msp/cacerts/${ORG_FACS_CA_NAME}-cert.pem"
  mv "${ORG_CRYPTO_PEER0}/msp/signcerts/"*  "${ORG_CRYPTO_PEER0}/msp/signcerts/${ORG_PEER0_FQDN}-cert.pem"

  if ! [ -d "${ORG_CRYPTO_PEER0}/msp/admincerts" ]; then
    mkdir -p "${ORG_CRYPTO_PEER0}/msp/admincerts"
  fi

  cp "${ORG_CRYPTO_USERS}/${ORG_ADMIN_ID}/msp/signcerts/"*    "${ORG_CRYPTO_PEER0}/msp/admincerts/${ORG_ADMIN_ID}-cert.pem"

  rm -rf  "${ORG_CRYPTO_PEER0}/msp/IssuerPublicKey"
  rm -rf  "${ORG_CRYPTO_PEER0}/msp/IssuerRevocationPublicKey"
  rm -rf  "${ORG_CRYPTO_PEER0}/msp/user"

fi


#
# org1.example.com/users/
#

# Admin1@org1.example.com

if ! [ -d "${ORG_CRYPTO_ADMIN}/msp/admincerts" ]; then
  mkdir -p "${ORG_CRYPTO_ADMIN}/msp/admincerts"
fi

cp "${ORG_CRYPTO_ADMIN}/msp/signcerts/"*  "${ORG_CRYPTO_ADMIN}/msp/admincerts/${ORG_ADMIN_ID}-cert.pem"

rm -rf  "${ORG_CRYPTO_ADMIN}/msp/IssuerPublicKey"
rm -rf  "${ORG_CRYPTO_ADMIN}/msp/IssuerRevocationPublicKey"
rm -rf  "${ORG_CRYPTO_ADMIN}/msp/user"

mv "${ORG_CRYPTO_ADMIN}/msp/cacerts/"*    "${ORG_CRYPTO_ADMIN}/msp/cacerts/${ORG_FACS_CA_NAME}-cert.pem"
mv "${ORG_CRYPTO_ADMIN}/msp/signcerts/"*  "${ORG_CRYPTO_ADMIN}/msp/signcerts/${ORG_ADMIN_ID}-cert.pem"


# User1@org1.example.com

if ! [ -d "${ORG_CRYPTO_USER1}/msp/admincerts" ]; then
  mkdir -p "${ORG_CRYPTO_USER1}/msp/admincerts"
fi

cp "${ORG_CRYPTO_USER1}/msp/signcerts/"*  "${ORG_CRYPTO_USER1}/msp/admincerts/${ORG_USER1_ID}-cert.pem"

rm -rf  "${ORG_CRYPTO_USER1}/msp/IssuerPublicKey"
rm -rf  "${ORG_CRYPTO_USER1}/msp/IssuerRevocationPublicKey"
rm -rf  "${ORG_CRYPTO_USER1}/msp/user"

mv "${ORG_CRYPTO_USER1}/msp/cacerts/"*    "${ORG_CRYPTO_USER1}/msp/cacerts/${ORG_FACS_CA_NAME}-cert.pem"
mv "${ORG_CRYPTO_USER1}/msp/signcerts/"*  "${ORG_CRYPTO_USER1}/msp/signcerts/${ORG_USER1_ID}-cert.pem"

set +e

exit 0