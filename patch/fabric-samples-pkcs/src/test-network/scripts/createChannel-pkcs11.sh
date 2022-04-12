#!/bin/bash

# imports  
. scripts/envVar.sh
. scripts/utils.sh

#pkcs11
. _pkcs.cfg

CHANNEL_NAME="$1"
DELAY="$2"
MAX_RETRY="$3"
VERBOSE="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

if [ ! -d "channel-artifacts" ]; then
	mkdir channel-artifacts
fi

createChannelTx() {

	infoln "======================================================================="
	infoln "[createChannel-pkcs11.sh::createChannelTx()]"
	infoln "> creating channel create transaction "
	infoln "======================================================================="

	set -x
	${_PKCS_FAB_SAMP_BIN}/configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
	res=$?
	{ set +x; } 2>/dev/null
  verifyResult $res "Failed to generate channel configuration transaction..."
}

createChannel() {

	infoln "======================================================================="
	infoln "[createChannel-pkcs11.sh::createChannel()]"
    infoln "> creating channel with PKCS11 "
	infoln "======================================================================="

	setGlobals 1
	# > CORE_PEER_LOCALMSPID=Org1MSP
	# > CORE_PEER_TLS_ROOTCERT_FILE=/home/ubuntu/fabric-samples/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
	# > CORE_PEER_MSPCONFIGPATH=/home/ubuntu/fabric-samples/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
	# > CORE_PEER_ADDRESS=localhost:7051

	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1

    export SOFTHSM2_CONF="${_PKCS_SHSM_CONF_FILE_PATH}"
	# https://github.com/hyperledger/fabric/pull/1900
	# 위와 같인 이슈로 fabric1.4.1에서는 환경변수에 값을 넘겨사용이 가능했으나,
	# fabric 2.x 대에서는 환경변수 사용이 불가하므로, core.yaml 파일에 BCCSP_PKCS11 사항을 입력하여 사용한다.
	# export CORE_PEER_BCCSP_DEFAULT=PKCS11
	# export CORE_PEER_BCCSP_PKCS11_LIBRARY=${_PKCS_LIB_PATH}
	# export CORE_PEER_BCCSP_PKCS11_PIN=${_PKCS_PIN}
	# export CORE_PEER_BCCSP_PKCS11_LABEL=${_PKCS_TOKEN}
	# export CORE_PEER_BCCSP_PKCS11_HASH=${_PKCS_HASH}
	# export CORE_PEER_BCCSP_PKCS11_SECURITY=${_PKCS_SECURITY}
	# export CORE_PEER_BCCSP_PKCS11_IMMUTABLE=${_PKCS_IMMUTABLE}

	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x

		${_PKCS_FAB_SAMP_BIN}/peer channel create -o localhost:7050 -c $CHANNEL_NAME \
		     --ordererTLSHostnameOverride orderer.example.com \
			  -f ./channel-artifacts/${CHANNEL_NAME}.tx \
			  --outputBlock $BLOCKFILE \
			  --tls \
			  --cafile $ORDERER_CA >&log.txt
		res=$?
		{ set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
		cat log.txt		
	done
	cat log.txt
	verifyResult $res "Channel creation failed"
}

# joinChannel ORG
joinChannel() {
 
  infoln "======================================================================="
  infoln "[createChannel-pkcs11.sh::joinChannel()]"
  infoln "> joining org1/org2 peer to the channel "
  infoln "======================================================================="

  #pkcs11
  #FABRIC_CFG_PATH=$PWD/../config/

  ORG=$1
  setGlobals $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
    ${_PKCS_FAB_SAMP_BIN}/peer channel join -b $BLOCKFILE >&log.txt
    res=$?
    { set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

setAnchorPeer() {

  infoln "======================================================================="
  infoln "[createChannel-pkcs11.sh::setAnchorPeer()]"
  infoln "Setting anchor peer for org1/org2 peer "
  infoln "======================================================================="

  ORG=$1  

  infoln "executing scripts/setAnchorPeer-pkcs11.sh in cli docker container , org=$ORG, channel=$CHANNEL_NAME"
  docker exec cli ./scripts/setAnchorPeer-pkcs11.sh $ORG $CHANNEL_NAME 

  if [ $? -ne 0 ]; then
    fatalln "Failed to execute  ./scripts/setAnchorPeer-pkcs11.sh in docker cli container "
  fi
}


export FABRIC_LOGGING_SPEC=${_PKCS_FAB_LOGGING}
export PATH=${PWD}/../bin:${PATH}
#export PATH=/opt/gopath/src/github.com/hyperledger/fabric/release/linux-amd64/bin/:${PATH}


#
# create channel create transaction
#

FABRIC_CFG_PATH=${PWD}/configtx
export FABRIC_CFG_PATH=${PWD}/configtx

## Create channeltx
infoln "Generating channel create transaction '${CHANNEL_NAME}.tx'"
createChannelTx


#
# create channel
#

if ! [ -f "${_PKCS_FAB_SAMP_CORE_ORDERER_YAML_PATH}/core.yaml" ] || \
	! [ -f "${_PKCS_FAB_SAMP_CORE_ORDERER_YAML_PATH}/orderer.yaml" ]; then
	fatalln "can't find file core.yaml or orderer.yaml for pkcs"
fi

#FABRIC_CFG_PATH=$PWD/../config/
FABRIC_CFG_PATH=${_PKCS_FAB_SAMP_CORE_ORDERER_YAML_PATH}
export FABRIC_CFG_PATH=${_PKCS_FAB_SAMP_CORE_ORDERER_YAML_PATH}
BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"

## Create channel
infoln "Creating channel ${CHANNEL_NAME}"
createChannel
successln "Channel '$CHANNEL_NAME' created"


#
# join channel
#

## Join all the peers to the channel
infoln "Joining org1 peer to the channel..."
joinChannel 1
infoln "Joining org2 peer to the channel..."
joinChannel 2


#
# set anchor peer for org1/org2 peer
#

## Set the anchor peers for each org in the channel
infoln "Setting anchor peer for org1..."
setAnchorPeer 1
infoln "Setting anchor peer for org2..."
setAnchorPeer 2


successln "Channel '$CHANNEL_NAME' joined"


infoln "======================================================================="
infoln "setting anchor peer finished successfully"
infoln "======================================================================="


######################################################################################################
#   #pkcs11 
#   cp  "organizations/fabric-ca-client-pkcs11/fabric-ca-client-config.yaml"  "${FABRIC_CA_CLIENT_HOME}/"
#   if [ $? -ne 0 ]; then
#    echo "[ERR] failed to copy fabric-ca-client-config.yaml to ${FABRIC_CA_CLIENT_HOME}/"
#    exit 1
#   fi

    #pkcs11
	#tls-cert.pem is automatically generated by farbic-ca-server
