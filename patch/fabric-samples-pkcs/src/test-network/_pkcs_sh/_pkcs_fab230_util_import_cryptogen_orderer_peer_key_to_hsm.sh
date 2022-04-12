#!/bin/bash

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname ${SCRIPT}`
SCRIPTNAME=`basename ${SCRIPT}`

cd ${SCRIPTPATH}

. ../_pkcs.cfg


FAB_SAMP_VER=2.3.0

# fabric-samples 1.4.1
# "${_PKCS_CFG_PATH}/crypto-config"

# fabric-samples 2.3.0
CRYPTOGEN_CRYPTO_PATH="${_PKCS_CFG_PATH}/organizations"

if ! [ -d "${CRYPTOGEN_CRYPTO_PATH}" ]; then
  echo "[ERR] can't find cryptogen crypto base path,${CRYPTOGEN_CRYPTO_PATH}"
  exit 1
fi

#==============================================================================#
# orderer.example.com  MSP/TLS
#==============================================================================#

ORGORDERER_CRYPTO=${CRYPTOGEN_CRYPTO_PATH}/ordererOrganizations/example.com

ORDERER_MSP=${ORGORDERER_CRYPTO}/orderers/orderer.example.com/msp

ORDERER_SVR_KEY=$(util_get_first_file_name_in_path "${ORDERER_MSP}" "keystore")
ORDERER_SVR_CERT=$(util_get_first_file_name_in_path "${ORDERER_MSP}" "signcerts")

chk_empty_exit "ORDERER_SVR_KEY" 1
chk_empty_exit "ORDERER_SVR_CERT" 1

set -e
ORDERER_SVR_CERT_FILE_PATH="${ORDERER_MSP}/signcerts/${ORDERER_SVR_CERT}"
ORDERER_SVR_CERT_PUBKEY_FILE_PATH=$(mktemp "/tmp/_tp.XXXXXXXXXXXXXXXX")
$(openssl x509 -in "${ORDERER_SVR_CERT_FILE_PATH}" -noout -pubkey > "${ORDERER_SVR_CERT_PUBKEY_FILE_PATH}")
ORDERER_SVR_CERT_SKI=$(get_ski_from_ecprime256v1_pub_file "${ORDERER_SVR_CERT_PUBKEY_FILE_PATH}")

ORDERER_SVR_KEY_HSM_ID=${ORDERER_SVR_CERT_SKI}
ORDERER_SVR_KEY_HSM_LABEL=${ORDERER_SVR_CERT_SKI}

# import  public key into hsm
export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
pkcs11-tool --write-object "${ORDERER_SVR_CERT_PUBKEY_FILE_PATH}" \
         --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type pubkey \
         --id ${ORDERER_SVR_KEY_HSM_ID} --label ${ORDERER_SVR_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

# import  private key
ORDERER_SVR_KEY_FILE_PATH="${ORDERER_MSP}/keystore/${ORDERER_SVR_KEY}"

pkcs11-tool --write-object "${ORDERER_SVR_KEY_FILE_PATH}" \
   --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type privkey \
   --id ${ORDERER_SVR_KEY_HSM_ID} --label ${ORDERER_SVR_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

set +

echo ""
echo "[INFO] importing orderer.example.com msp key/cert is success"
echo ""

ORDERER_TLS=${ORGORDERER_CRYPTO}/orderers/orderer.example.com/tls

ORDERER_SVR_TLS_KEY=$(util_get_first_file_name_in_path "${ORDERER_TLS}" "keystore")
ORDERER_SVR_TLS_CERT=$(util_get_first_file_name_in_path "${ORDERER_TLS}" "signcerts")

chk_empty_exit "ORDERER_SVR_TLS_KEY" 1
chk_empty_exit "ORDERER_SVR_TLS_CERT" 1

set -e
ORDERER_SVR_TLS_CERT_FILE_PATH="${ORDERER_TLS}/signcerts/${ORDERER_SVR_TLS_CERT}"
ORDERER_SVR_TLS_CERT_PUBKEY_FILE_PATH=$(mktemp "/tmp/_tp.XXXXXXXXXXXXXXXX")
$(openssl x509 -in "${ORDERER_SVR_TLS_CERT_FILE_PATH}" -noout -pubkey > "${ORDERER_SVR_TLS_CERT_PUBKEY_FILE_PATH}")
ORDERER_SVR_TLS_CERT_SKI=$(get_ski_from_ecprime256v1_pub_file "${ORDERER_SVR_TLS_CERT_PUBKEY_FILE_PATH}")

ORDERER_SVR_TLS_KEY_HSM_ID=${ORDERER_SVR_TLS_CERT_SKI}
ORDERER_SVR_TLS_KEY_HSM_LABEL=${ORDERER_SVR_TLS_CERT_SKI}

# import  public key into hsm
export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
pkcs11-tool --write-object "${ORDERER_SVR_TLS_CERT_PUBKEY_FILE_PATH}" \
         --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type pubkey \
         --id ${ORDERER_SVR_TLS_KEY_HSM_ID} --label ${ORDERER_SVR_TLS_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

# import  private key
ORDERER_SVR_TLS_KEY_FILE_PATH="${ORDERER_TLS}/keystore/${ORDERER_SVR_TLS_KEY}"

pkcs11-tool --write-object "${ORDERER_SVR_TLS_KEY_FILE_PATH}" \
   --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type privkey \
   --id ${ORDERER_SVR_TLS_KEY_HSM_ID} --label ${ORDERER_SVR_TLS_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

echo ""
echo "[INFO] importing orderer.example.com tls key/cert is success"
echo ""

set +e


#==============================================================================#
# peer0.org1.example.com  MSP/TLS
#==============================================================================#

ORG1_CRYPTO=${CRYPTOGEN_CRYPTO_PATH}/peerOrganizations/org1.example.com

ORG1_PEER0_MSP=${ORG1_CRYPTO}/peers/peer0.org1.example.com/msp

ORG1_PEER0_SVR_KEY=$(util_get_first_file_name_in_path "${ORG1_PEER0_MSP}" "keystore")
ORG1_PEER0_SVR_CERT=$(util_get_first_file_name_in_path "${ORG1_PEER0_MSP}" "signcerts")

chk_empty_exit "ORG1_PEER0_SVR_KEY" 1
chk_empty_exit "ORG1_PEER0_SVR_CERT" 1

set -e
ORG1_PEER0_SVR_CERT_FILE_PATH="${ORG1_PEER0_MSP}/signcerts/${ORG1_PEER0_SVR_CERT}"
ORG1_PEER0_SVR_CERT_PUBKEY_FILE_PATH=$(mktemp "/tmp/_tp.XXXXXXXXXXXXXXXX")
$(openssl x509 -in "${ORG1_PEER0_SVR_CERT_FILE_PATH}" -noout -pubkey > "${ORG1_PEER0_SVR_CERT_PUBKEY_FILE_PATH}")
ORG1_PEER0_SVR_CERT_SKI=$(get_ski_from_ecprime256v1_pub_file "${ORG1_PEER0_SVR_CERT_PUBKEY_FILE_PATH}")

ORG1_PEER0_SVR_KEY_HSM_ID=${ORG1_PEER0_SVR_CERT_SKI}
ORG1_PEER0_SVR_KEY_HSM_LABEL=${ORG1_PEER0_SVR_CERT_SKI}

# import  public key into hsm
export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
pkcs11-tool --write-object "${ORG1_PEER0_SVR_CERT_PUBKEY_FILE_PATH}" \
         --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type pubkey \
         --id ${ORG1_PEER0_SVR_KEY_HSM_ID} --label ${ORG1_PEER0_SVR_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

# import  private key
ORG1_PEER0_SVR_KEY_FILE_PATH="${ORG1_PEER0_MSP}/keystore/${ORG1_PEER0_SVR_KEY}"

pkcs11-tool --write-object "${ORG1_PEER0_SVR_KEY_FILE_PATH}" \
   --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type privkey \
   --id ${ORG1_PEER0_SVR_KEY_HSM_ID} --label ${ORG1_PEER0_SVR_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

set +

echo ""
echo "[INFO] importing peer0.org1.example.com msp key/cert is success"
echo ""

ORG1_PEER0_TLS=${ORG1_CRYPTO}/peers/peer0.org1.example.com/tls

ORG1_PEER0_SVR_TLS_KEY=$(util_get_first_file_name_in_path "${ORG1_PEER0_TLS}" "keystore")
ORG1_PEER0_SVR_TLS_CERT=$(util_get_first_file_name_in_path "${ORG1_PEER0_TLS}" "signcerts")

chk_empty_exit "ORG1_PEER0_SVR_TLS_KEY" 1
chk_empty_exit "ORG1_PEER0_SVR_TLS_CERT" 1

set -e
ORG1_PEER0_SVR_TLS_CERT_FILE_PATH="${ORG1_PEER0_TLS}/signcerts/${ORG1_PEER0_SVR_TLS_CERT}"
ORG1_PEER0_SVR_TLS_CERT_PUBKEY_FILE_PATH=$(mktemp "/tmp/_tp.XXXXXXXXXXXXXXXX")
$(openssl x509 -in "${ORG1_PEER0_SVR_TLS_CERT_FILE_PATH}" -noout -pubkey > "${ORG1_PEER0_SVR_TLS_CERT_PUBKEY_FILE_PATH}")
ORG1_PEER0_SVR_TLS_CERT_SKI=$(get_ski_from_ecprime256v1_pub_file "${ORG1_PEER0_SVR_TLS_CERT_PUBKEY_FILE_PATH}")

ORG1_PEER0_SVR_TLS_KEY_HSM_ID=${ORG1_PEER0_SVR_TLS_CERT_SKI}
ORG1_PEER0_SVR_TLS_KEY_HSM_LABEL=${ORG1_PEER0_SVR_TLS_CERT_SKI}

# import  public key into hsm
export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
pkcs11-tool --write-object "${ORG1_PEER0_SVR_TLS_CERT_PUBKEY_FILE_PATH}" \
         --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type pubkey \
         --id ${ORG1_PEER0_SVR_TLS_KEY_HSM_ID} --label ${ORG1_PEER0_SVR_TLS_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

# import  private key
ORG1_PEER0_SVR_TLS_KEY_FILE_PATH="${ORG1_PEER0_TLS}/keystore/${ORG1_PEER0_SVR_TLS_KEY}"

pkcs11-tool --write-object "${ORG1_PEER0_SVR_TLS_KEY_FILE_PATH}" \
   --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type privkey \
   --id ${ORG1_PEER0_SVR_TLS_KEY_HSM_ID} --label ${ORG1_PEER0_SVR_TLS_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

echo ""
echo "[INFO] importing peer0.org1.example.com tls key/cert is success"
echo ""

set +e


exit 1

