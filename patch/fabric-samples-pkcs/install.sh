#!/bin/bash

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname ${SCRIPT}`
SCRIPTNAME=`basename ${SCRIPT}`
cd ${SCRIPTPATH}


PRM_PATCH_PATH=$1

if [ -z "${PRM_PATCH_PATH}" ]; then
  echo "usage)"
  echo " ${SCRIPTNAME} [fabric-samples-path] "
  echo " ${SCRIPTNAME} /opt/gopath/src/github.com/hyperledger/fabric-samples "
  exit 1
fi

if ! [ -d "${PRM_PATCH_PATH}/test-network" ] ||
   ! [ -d "${PRM_PATCH_PATH}/fabcar" ]; then
  echo "[ERR] invalid fabric-samples path, can't find test-network, fabcar"
  exit 1
fi

echo ""
echo "========================================================================="
echo "[INFO] copying patch file to ${PRM_PATCH_PATH} "
echo "========================================================================="
echo ""

cp -rPa "./src/"*  "${PRM_PATCH_PATH}"

if [ $? -ne 0 ]; then
  echo "[ERR] failed to copy patch files to ${PRM_PATCH_PATH}"
  exit 1
fi

echo "[INFO] patch is done successfully"

exit 0

