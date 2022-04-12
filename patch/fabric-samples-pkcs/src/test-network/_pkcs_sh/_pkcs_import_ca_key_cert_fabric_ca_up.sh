#!/bin/bash

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname ${SCRIPT}`
SCRIPTNAME=`basename ${SCRIPT}`

cd ${SCRIPTPATH}

. ../_pkcs.cfg


PRM_FABRIC_CA_UP=$1

if [ "${PRM_FABRIC_CA_UP}" != "1" ]; then
  PRM_FABRIC_CA_UP=0
fi


#==============================================================================
# ca root key/cert 를 HSM 으로 import 
#==============================================================================

#
# ca.example.com
#
set -e

ORGORDERER_CA_FQDN=ca.example.com
ORGORDERER_CA_CERT_FILE_PATH="${_PKCS_CFG_PATH}/_pkcs_data/docker/${ORGORDERER_CA_FQDN}/imp-key-cert/ca/${ORGORDERER_CA_FQDN}-cert.pem"

ORGORDERER_CA_CERT_PUBKEY_FILE_PATH=$(mktemp "/tmp/_tp.XXXXXXXXXXXXXXXX")
$(openssl x509 -in "${ORGORDERER_CA_CERT_FILE_PATH}" -noout -pubkey > "${ORGORDERER_CA_CERT_PUBKEY_FILE_PATH}")

ORGORDERER_CA_CERT_SKI=$(get_ski_from_ecprime256v1_pub_file "${ORGORDERER_CA_CERT_PUBKEY_FILE_PATH}")

ORGORDERER_CA_KEY_HSM_ID=${ORGORDERER_CA_CERT_SKI}
ORGORDERER_CA_KEY_HSM_LABEL=${ORGORDERER_CA_CERT_SKI}

# import  public key into hsm
export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
pkcs11-tool --write-object "${ORGORDERER_CA_CERT_PUBKEY_FILE_PATH}" \
         --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type pubkey \
         --id ${ORGORDERER_CA_KEY_HSM_ID} --label ${ORGORDERER_CA_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

# import  private key
ORGORDERER_CA_KEY_FILE_PATH="${_PKCS_CFG_PATH}/_pkcs_data/docker/${ORGORDERER_CA_FQDN}/imp-key-cert/ca/${ORGORDERER_CA_KEY_HSM_ID}_sk"

pkcs11-tool --write-object "${ORGORDERER_CA_KEY_FILE_PATH}" \
   --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type privkey \
   --id ${ORGORDERER_CA_KEY_HSM_ID} --label ${ORGORDERER_CA_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

pkcs11-tool --list-objects --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --module "${_PKCS_LIB_PATH}"

set +e


#
# ca.org1.example.com
#

set -e

ORG1_CA_FQDN=ca.org1.example.com
ORG1_CA_CERT_FILE_PATH="${_PKCS_CFG_PATH}/_pkcs_data/docker/${ORG1_CA_FQDN}/imp-key-cert/ca/${ORG1_CA_FQDN}-cert.pem"

ORG1_CA_CERT_PUBKEY_FILE_PATH=$(mktemp "/tmp/_tp.XXXXXXXXXXXXXXXX")
$(openssl x509 -in "${ORG1_CA_CERT_FILE_PATH}" -noout -pubkey > "${ORG1_CA_CERT_PUBKEY_FILE_PATH}")

ORG1_CA_CERT_SKI=$(get_ski_from_ecprime256v1_pub_file "${ORG1_CA_CERT_PUBKEY_FILE_PATH}")

ORG1_CA_KEY_HSM_ID=${ORG1_CA_CERT_SKI}
ORG1_CA_KEY_HSM_LABEL=${ORG1_CA_CERT_SKI}

# import  public key into hsm
export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
pkcs11-tool --write-object "${ORG1_CA_CERT_PUBKEY_FILE_PATH}" \
         --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type pubkey \
         --id ${ORG1_CA_KEY_HSM_ID} --label ${ORG1_CA_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

# import  private key
ORG1_CA_KEY_FILE_PATH="${_PKCS_CFG_PATH}/_pkcs_data/docker/${ORG1_CA_FQDN}/imp-key-cert/ca/${ORG1_CA_KEY_HSM_ID}_sk"

pkcs11-tool --write-object "${ORG1_CA_KEY_FILE_PATH}" \
   --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --type privkey \
   --id ${ORG1_CA_KEY_HSM_ID} --label ${ORG1_CA_KEY_HSM_LABEL} --module "${_PKCS_LIB_PATH}"

pkcs11-tool --list-objects --login --token-label ${_PKCS_TOKEN} --pin ${_PKCS_PIN} --module "${_PKCS_LIB_PATH}"

set +e


#==============================================================================
# fabric-ca-server 생성
# > ca.example.com
# > ca.org1.example.com
#==============================================================================

if [ "${PRM_FABRIC_CA_UP}" == "0" ]; then
  exit 0
fi


docker-compose -f "${_PKCS_FAB_SAMP_DK_COMPOSE_FILE_PATH}" up -d  --force-recreate  ${ORGORDERER_CA_FQDN}  ${ORG1_CA_FQDN}

if [ $? -ne 0 ]; then
  echo "[ERR] failed to create fabric-ca-server"
  exit 1
fi

sleep 1

await_container_start  ${ORGORDERER_CA_FQDN} 1
await_container_start  ${ORG1_CA_FQDN} 1

await_svr_port ${ORGORDERER_CA_FQDN} 7054 1
await_svr_port ${ORG1_CA_FQDN} 8054 1

echo ""
echo "[INFO] created  fabric-ca-server   ${ORGORDERER_CA_FQDN}  ${ORG1_CA_FQDN} "
echo ""

