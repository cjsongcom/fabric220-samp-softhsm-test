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
# orderer - example.com
#==============================================================================#

ORGORDERER_CRYPTO=${CRYPTOGEN_CRYPTO_PATH}/ordererOrganizations/example.com
ORGORDERER_CA_MSP=${ORGORDERER_CRYPTO}/msp

ORGORDERER_CA_KEY=$(util_get_first_file_name_in_path "${ORGORDERER_CA_MSP}" "keystore")
ORGORDERER_CA_CERT=$(util_get_first_file_name_in_path "${ORGORDERER_CA_MSP}" "cacerts")
#ORGORDERER_TLS_CA_CERT=$(util_get_first_file_name_in_path "${ORGORDERER_CA_MSP}" "tlscacerts")

chk_empty_exit "ORGORDERER_CA_KEY" 1
chk_empty_exit "ORGORDERER_CA_CERT" 1

ORGORDERER_FCAS_FQDN=ca.example.com
ORGORDERER_DK_IMP_KEY_CERT_PATH=${_PKCS_DATA_PATH}/docker/${ORGORDERER_FCAS_FQDN}/imp-key-cert

if [ -d "${ORGORDERER_DK_IMP_KEY_CERT_PATH}/ca" ]; then
  rm -rf "${ORGORDERER_DK_IMP_KEY_CERT_PATH}/ca"

  if [ $? -ne 0 ]; then
    echo "[ERR] failed to delete path, ${ORGORDERER_DK_IMP_KEY_CERT_PATH}/ca"
    exit 1
  fi
fi

set -e
mkdir -p "${ORGORDERER_DK_IMP_KEY_CERT_PATH}/ca"
cp "${ORGORDERER_CA_MSP}/keystore/${ORGORDERER_CA_KEY}" "${ORGORDERER_DK_IMP_KEY_CERT_PATH}/ca/"
cp "${ORGORDERER_CA_MSP}/cacerts/${ORGORDERER_CA_CERT}" "${ORGORDERER_DK_IMP_KEY_CERT_PATH}/ca/${ORGORDERER_FCAS_FQDN}-cert.pem"
set +e


#==============================================================================#
# org1 - org1.example.com
#==============================================================================#

ORG1_CRYPTO=${CRYPTOGEN_CRYPTO_PATH}/peerOrganizations/org1.example.com
ORG1_CA_MSP=${ORG1_CRYPTO}/msp

ORG1_CA_KEY=$(util_get_first_file_name_in_path "${ORG1_CA_MSP}" "keystore")
ORG1_CA_CERT=$(util_get_first_file_name_in_path "${ORG1_CA_MSP}" "cacerts")

chk_empty_exit "ORG1_CA_KEY" 1
chk_empty_exit "ORG1_CA_CERT" 1

ORG1_FCAS_FQDN=ca.org1.example.com
ORG1_DK_IMP_KEY_CERT_PATH=${_PKCS_DATA_PATH}/docker/${ORG1_FCAS_FQDN}/imp-key-cert

if [ -d "${ORG1_DK_IMP_KEY_CERT_PATH}/ca" ]; then
  rm -rf "${ORG1_DK_IMP_KEY_CERT_PATH}/ca"

  if [ $? -ne 0 ]; then
    echo "[ERR] failed to delete path, ${ORG1_DK_IMP_KEY_CERT_PATH}/ca"
    exit 1
  fi
fi

set -e
mkdir -p "${ORG1_DK_IMP_KEY_CERT_PATH}/ca"
cp "${ORG1_CA_MSP}/keystore/${ORG1_CA_KEY}" "${ORG1_DK_IMP_KEY_CERT_PATH}/ca/"
cp "${ORG1_CA_MSP}/cacerts/${ORG1_CA_CERT}" "${ORG1_DK_IMP_KEY_CERT_PATH}/ca/${ORG1_FCAS_FQDN}-cert.pem"
set +e

