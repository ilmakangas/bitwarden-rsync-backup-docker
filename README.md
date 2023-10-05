# bitwarden-rsync-backup-docker
Docker container for backing up Bitwarden vault with rsync.

When executed, the container connects to Bitwarden using credentials supplied in the config file and backs up the vault using rsync to a chosen destination. 
The backup is automatically encrypted with [age](https://github.com/FiloSottile/age).

## Prerequisites
You need to get a Bitwarden API key from the Bitwarden Web UI.

## Usage

1. Clone this repository
2. Build the image

       docker build .

3. Create a directory for the config
4. Provide the config as file config.env in the config directory
   
   Config format

       export BW_CLIENTSECRET=<Bitwarden client secret here>
       export BW_CLIENTID=<Bitwarden client ID here>
       export BW_PASSWORD=<Bitwarden vault master password here>
       export RSYNC_SSH_KEYFILE=<Name of SSH key file in config volume (example: id_ed25519)>
       export RSYNC_TARGET=<Rsync target for backups (example: backup-user@127.0.0.1::backups/bitwarden/">
5. Create a SSH keypair and put the private key into the config directory

       ssh-keygen -t id_ed25519 -o config/id_ed25519
8. Configure your rsync target server to accept SSH authentication using the generated key.

9. Execute the container providing the config directory as a volume. The volume must be mounted to /config

       docker run --rm -v ./configdirectory:/config -it <image_name>

10. The container backs up your vault to the rsync target. You can get the age keyfile from the configuration directory after first run of the container.
   On subsequent executions the same keyfile is automatically used.

To restore your backup use the [age](https://github.com/FiloSottile/age) tool to decrypt the backup file.
