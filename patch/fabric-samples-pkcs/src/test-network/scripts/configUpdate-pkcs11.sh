#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# import utils
. scripts/envVar.sh

# fetchChannelConfig <org> <channel_id> <output_json>
# Writes the current channel config for a given channel to a JSON file
# NOTE: this must be run in a CLI container since it requires configtxlator 
fetchChannelConfig() {

  infoln "======================================================================="
  infoln "configUpdate-pkcs11.sh::fetchChannelConfig()"
  infoln " > Fetching the most recent configuration block for the channel"
  infoln "======================================================================="

  ORG=$1
  CHANNEL=$2
  OUTPUT=$3

  setGlobals $ORG
  local _res=

  infoln "Fetching the most recent configuration block for the channel"
  
  (
    # cli 컨테이너 work 폴더가 /opt/gopath/src/github.com/hyperledger/fabric/peer 인데
    # 이곳에 파일 생성이 불가하여 일시적으로 /tmp/로 변경
    # 현재 디렉토리를 자체를 /tmp 로 바꾸면 CORE_PEER_MSPCONFIGPATH 경로가 꼬여서 문제 ${PWD}로 되어있기때문  
    # > setGlobals() {
    # > export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    # > }
    set -x

    cd /tmp

    peer channel fetch config config_block.pb \
      -o orderer.example.com:7050 \
      --ordererTLSHostnameOverride orderer.example.com \
      -c $CHANNEL \
      --tls \
      --cafile $ORDERER_CA
    
    _res=$?
    
    { set +x; } 2>/dev/null

    if [ ${_res} -ne 0 ]; then
      fatalln "Can't fetch channel config block.."
    fi
  
    infoln "Decoding config block to JSON and isolating config to ${OUTPUT}"

    set -x
    configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config >"${OUTPUT}"
    
    _res=$?
    { set +x; } 2>/dev/null

    if [ ${_res} -ne 0 ]; then
      fatalln "Can't decode config_block.pb .."
    fi

    infoln "generated decoded config file at ${OUTPUT}"
  )

  return $?
}

# createConfigUpdate <channel_id> <original_config.json> <modified_config.json> <output.pb>
# Takes an original and modified config, and produces the config update tx
# which transitions between the two
# NOTE: this must be run in a CLI container since it requires configtxlator 
createConfigUpdate() {
  CHANNEL=$1
  ORIGINAL=$2
  MODIFIED=$3
  OUTPUT=$4

  infoln "====================================================================="
  infoln "configUpdate-pkcs11.sh::createConfigupdate()"
  infoln " > creating config update Channel=$1, original=$2, modified=$3, output=$4"
  infoln "====================================================================="

  local _res

  (
    set -x
    cd /tmp
  
    configtxlator proto_encode --input "${ORIGINAL}" --type common.Config > original_config.pb
    verifyResult $? "failed to execute, proto_encode, ${ORIGINAL}, original_config.pb"

    configtxlator proto_encode --input "${MODIFIED}" --type common.Config > modified_config.pb
    verifyResult $? "failed to execute, proto_encode, ${MODIFIED},  modified_config.pb"

    configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb --updated modified_config.pb > config_update.pb
    verifyResult $? "failed to execute, compute_update"

    configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate > config_update.json
    verifyResult $? "failed to execute, proto_decode, 1"

    echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . >config_update_in_envelope.json
    verifyResult $? "failed to execute 1"

    configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope >"${OUTPUT}"
    verifyResult $? "failed to execute 1"

    { set +x; } 2>/dev/null
  )

  return $?
}

# signConfigtxAsPeerOrg <org> <configtx.pb>
# Set the peerOrg admin of an org and sign the config update
signConfigtxAsPeerOrg() {
  ORG=$1
  CONFIGTXFILE=$2
  setGlobals $ORG
  set -x
  peer channel signconfigtx -f "${CONFIGTXFILE}"
  { set +x; } 2>/dev/null
}
