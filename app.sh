#!/bin/bash
set -e
set -o pipefail

CONFDIR=/config
CONFFILE=$CONFDIR/config.env

AGE_KEYFILE_NAME=age.key
AGE_KEYFILE=$CONFDIR/$AGE_KEYFILE_NAME
BACKUPFILE=/tmp/$(date +"backup-%d-%m-%Y-%H-%M-%S.json.age")

cleanup_logout() {
	echo "AFTER_FAIL: Cleanup, logging out of Bitwarden"
	bw logout
}
[ ! -d $CONFDIR ] && { echo "FAIL: Config volume $CONFDIR not mounted"; exit 1; }
[ ! -f $CONFFILE ] && { echo "FAIL: Config file $CONFFILE doesnt exist"; exit 1; }
[ ! -n "$BW_CLIENTID"] && { echo "FAIL: BW_CLIENTID not set"; exit 1; }
[ ! -n "$BW_CLIENTSECRET"] && { echo "FAIL: BW_CLIENTSECRET not set"; exit 1; }
[ ! -n "$BW_PASSWORD"] && { echo "FAIL: BW_PASSWORD not set"; exit 1; }

if [ ! -f $AGE_KEYFILE ]; then
	echo "NOTICE: $AGE_KEYFILE keyfile doesnt exist, creating "
	age-keygen -o $AGE_KEYFILE > /dev/null
fi

[ $(cat $AGE_KEYFILE | wc -l) != 3 ] && { echo "FAIL: Invalid AGE keyfile format"; exit 1; }
echo "INFO: AGE keyfile is available from the config volume with name: $AGE_KEYFILE_NAME"

AGE_PUBKEY=$(cat $AGE_KEYFILE | awk -F ' ' "NR==2 { print \$4 }")
echo "INFO: AGE public key: $AGE_PUBKEY"
source $CONFFILE

echo "INFO: Logging in to Bitwarden"
bw login --apikey --raw || { echo "FAIL: Bitwarden login failed with status $?"; exit 1; }

echo "INFO: Unlocking Bitwarden vault"
BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw) || { echo "FAIL: Bitwarden unlock failed with status $?";
	cleanup_logout; exit 1; }

echo "INFO: Exporting and encrypting the vault"
bw export --session $BW_SESSION --format json --raw | age -r $AGE_PUBKEY > $BACKUPFILE || 
	{ echo "FAIL: Export or encrypt failed with status $?"; cleanup_logout; exit 1; }

echo "INFO: Verifying successful backup"
[ $(age --decrypt -i $AGE_KEYFILE $BACKUPFILE | awk "NR==1 { print }") != "{" ] && 
	{ echo "FAIL: Backup verification failed with status $?"; cleanup_logout; exit 1; }

echo "INFO: Verified successfully, logging out of Bitwarden"
bw logout

echo "INFO: Rsyncing file to target"
rsync -av -e "ssh -o StrictHostKeyChecking=accept-new -i $CONFDIR/$RSYNC_SSH_KEYFILE" $BACKUPFILE $RSYNC_TARGET || 
	{ echo "FAIL: Rsync failed with status $?"; exit 1; }
rm $BACKUPFILE
echo "INFO: Backup task completed"
