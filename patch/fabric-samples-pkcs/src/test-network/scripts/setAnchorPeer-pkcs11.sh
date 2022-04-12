#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# import utils
. scripts/envVar.sh
. scripts/configUpdate-pkcs11.sh


# NOTE: this must be run in a CLI container since it requires jq and configtxlator 
createAnchorPeerUpdate() {

  infoln "======================================================================="
  infoln "setAnchorPeer-pkcs11.sh::createAnchorPeerUpdate()"
  infoln "======================================================================="

  local _res
  infoln "Fetching channel config for channel $CHANNEL_NAME"

  fetchChannelConfig $ORG $CHANNEL_NAME ${CORE_PEER_LOCALMSPID}config.json

  infoln "Generating anchor peer update transaction for Org${ORG} on channel $CHANNEL_NAME"

  if [ $ORG -eq 1 ]; then
    HOST="peer0.org1.example.com"
    PORT=7051
  elif [ $ORG -eq 2 ]; then
    HOST="peer0.org2.example.com"
    PORT=9051
  elif [ $ORG -eq 3 ]; then
    HOST="peer0.org3.example.com"
    PORT=11051
  else
    errorln "Org${ORG} unknown"
  fi

  (
    set -x
    cd /tmp

    # Modify the configuration to append the anchor peer 
    jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'$HOST'","port": '$PORT'}]},"version": "0"}}' ${CORE_PEER_LOCALMSPID}config.json > ${CORE_PEER_LOCALMSPID}modified_config.json
    _res=$?
    { set +x; } 2>/dev/null

    if [ $? -ne 0 ]; then
      fatalln "failed to create anchor peer update json file=${CORE_PEER_LOCALMSPID}modified_config.json.."
    fi

    # Compute a config update, based on the differences between 
    # {orgmsp}config.json and {orgmsp}modified_config.json, write
    # it as a transaction to {orgmsp}anchors.tx
    set -x
    createConfigUpdate ${CHANNEL_NAME} ${CORE_PEER_LOCALMSPID}config.json \
                                      ${CORE_PEER_LOCALMSPID}modified_config.json \
                                      ${CORE_PEER_LOCALMSPID}anchors.tx
    _res=$?
    { set +x; } 2>/dev/null

    if [ ${_res} -ne 0 ]; then
      fatalln "failed to create config update transaction file=${CORE_PEER_LOCALMSPID}modified_config.json.."
    fi
  )

}

updateAnchorPeer() {

  infoln "======================================================================="
  infoln "setAnchorPeer-pkcs11.sh::updateAnchorPeer()"
  infoln "> peer channel update .. with ${CORE_PEER_LOCALMSPID}anchors.tx"
  infoln "======================================================================="

  local _res

  (
  set -x
  cd /tmp

  peer channel update -o orderer.example.com:7050 \
      --ordererTLSHostnameOverride orderer.example.com \
      -c $CHANNEL_NAME \
      -f ${CORE_PEER_LOCALMSPID}anchors.tx \
      --tls \
      --cafile $ORDERER_CA >& log-updateAnchorPeer.txt

  _res=$?
  
  set +x
  cat log-updateAnchorPeer.txt

  verifyResult ${_res} "Anchor peer update failed"
  successln "Anchor peer set for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"  
  )

}


#
# entry
#

ORG=$1
CHANNEL_NAME=$2
setGlobalsCLI $ORG

createAnchorPeerUpdate 

updateAnchorPeer 
