while getopts c:o:m:p: flag
do
   case "${flag}" in
      c) CHANNEL=${OPTARG};;
      o) ORGANIZATION=${OPTARG};;
      m) MSP=${OPTARG};;
      p) PORT=${OPTARG};;
   esac
done
echo "Channel: $CHANNEL";
echo "Org: $ORGANIZATION";
echo "MSP: $MSP";
local TEMP_PATH=$(dirname "$PWD")
HOME_PATH=$(dirname "$TEMP_PATH")

# # export TEST_NETWORK_HOME="${PWD}/.."
# . ${HOME_PATH}/scripts/configUpdate.sh
. ${HOME_PATH}/scripts/envVar.sh
. ${HOME_PATH}/scripts/utils.sh

function create-org() {
   echo "hello world"
   #the ../../organizations is beacause the script is inside the my scripts folder
   cryptogen generate --config=../../add$ORGANIZATION/$ORGANIZATION-crypto.yaml --output="../../organizations" || echo "Error crypto material"

   export FABRIC_CFG_PATH=${HOME_PATH}/add${ORGANIZATION}
   set -x
   echo "FABRIC_CFG_PATH ${FABRIC_CFG_PATH}"
   configtxgen -printOrg ${MSP}MSP > ../../organizations/peerOrganizations/${ORGANIZATION}.example.com/${ORGANIZATION}.json || echo "Erro printing"

   docker-compose -f ../../add${ORGANIZATION}/docker/docker-compose-${ORGANIZATION}.yaml up -d || echo "Error docker"
}

function updateChannel(){
   . ${HOME_PATH}/scripts/configUpdate.sh 
   echo "test network home: $TEST_NETWORK_HOME";
   echo "ORGANIZATION: ${ORGANIZATION}";
   export FABRIC_CFG_PATH=${HOME_PATH}/add${ORGANIZATION}/docker/peercfg

   ORDERER_CA=${HOME_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
   infoln "Creating config transaction to add org to network"

   # Fetch the config for the channel, writing it to config.json
   fetchChannelConfig 1 ${CHANNEL} ${HOME_PATH}/channel-artifacts/config.json

   # Modify the configuration to append the new org
   set -x
   jq -s ".[0] * {"channel_group":{"groups":{"Application":{"groups": {"${MSP}MSP":.[1]}}}}}" ${HOME_PATH}/channel-artifacts/config.json ${HOME_PATH}/organizations/peerOrganizations/${ORGANIZATION}.example.com/${ORGANIZATION}.json > ${HOME_PATH}/channel-artifacts/modified_config.json
   { set +x; } 2>/dev/null

   # Compute a config update, based on the differences between config.json and modified_config.json, write it as a transaction to ${org}_update_in_envelope.pb
   createConfigUpdate ${CHANNEL} ${HOME_PATH}/channel-artifacts/config.json ${HOME_PATH}/channel-artifacts/modified_config.json ${HOME_PATH}/channel-artifacts/${ORGANIZATION}_update_in_envelope.pb

   infoln "Signing config transaction"
   signConfigtxAsPeerOrg 1 ${HOME_PATH}/channel-artifacts/${ORGANIZATION}_update_in_envelope.pb

   infoln "Submitting transaction from a different peer (peer0.org2) which also signs it"
   setGlobals 2
   set -x
   peer channel update -f ${HOME_PATH}/channel-artifacts/${ORGANIZATION}_update_in_envelope.pb -c ${CHANNEL} -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA"
   { set +x; } 2>/dev/null

   successln "Config transaction to add ${ORGANIZATION} to network submitted"
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}

function joinChannel(){
   export FABRIC_CFG_PATH=${HOME_PATH}/add${ORGANIZATION}/docker/peercfg
   export ORDERER_CA=${HOME_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem 
   export CORE_PEER_LOCALMSPID=${MSP}
   export CORE_PEER_TLS_ROOTCERT_FILE=${HOME_PATH}/organizations/peerOrganizations/${ORGANIZATION}.example.com/users/Admin@${ORGANIZATION}.example.com/tls/ca.crt
   export CORE_PEER_MSPCONFIGPATH=${HOME_PATH}/organizations/peerOrganizations/${ORGANIZATION}.example.com/users/Admin@${ORGANIZATION}.example.com/msp
   export CORE_PEER_ADDRESS=localhost:${PORT}

   BLOCKFILE="${HOME_PATH}/channel-artifacts/${CHANNEL}.block"

   echo "Fetching channel config block from orderer..."
   set -x
   peer channel fetch 0 $BLOCKFILE -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL --tls --cafile "$ORDERER_CA" >&log.txt
   res=$?
   { set +x; } 2>/dev/null
   cat log.txt
   verifyResult $res "Fetching config block from orderer has failed"

   infoln "Joining org3 peer to the channel..."
   rc=1
   COUNTER=1
   MAX_RETRY=5
   DELAY=3
   ## Sometimes Join takes time, hence retry
   while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
      sleep $DELAY
      set -x
      peer channel join -b $BLOCKFILE >&log.txt
      res=$?
      { set +x; } 2>/dev/null
      let rc=$res
      COUNTER=$(expr $COUNTER + 1)
   done
   cat log.txt
   verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORGANIZATION} has failed to join channel '$CHANNEL' "

   infoln "Setting anchor peer for org3..."
   setAnchorPeer 3

   successln "Channel '$CHANNEL' joined"
   successln "${ORGANIZATION} peer successfully added to network"
}
# create-org
# updateChannel
joinChannel

