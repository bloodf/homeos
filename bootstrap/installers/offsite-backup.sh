#!/usr/bin/env bash
# Configure restic offsite repo. Adds second backup target alongside local NAS.
set -euo pipefail
ENV=/etc/homeos/backup.env
mkdir -p /etc/homeos
touch "$ENV"; chmod 600 "$ENV"

echo "== offsite backup =="
echo "  1) Backblaze B2"
echo "  2) Storj"
echo "  3) Hetzner Storage Box (sftp)"
echo "  4) Generic S3"
echo "  5) rclone remote (any of 70+ providers)"
read -r -p "choice [1-5]: " c

case "$c" in
  1)
    read -r -p "B2 account ID: " id
    read -r -s -p "B2 application key: " key; echo
    read -r -p "bucket: " bucket
    cat >>"$ENV" <<EOF
RESTIC_REPOSITORY_OFFSITE=b2:${bucket}
B2_ACCOUNT_ID=${id}
B2_ACCOUNT_KEY=${key}
EOF
    ;;
  2)
    read -r -p "Storj access grant: " grant
    read -r -p "bucket: " bucket
    apt-get install -y rclone || true
    cat >>"$ENV" <<EOF
RESTIC_REPOSITORY_OFFSITE=rclone:storj:${bucket}
RCLONE_CONFIG_STORJ_TYPE=storj
RCLONE_CONFIG_STORJ_ACCESS_GRANT=${grant}
EOF
    ;;
  3)
    read -r -p "user@host:port (e.g. u123@u123.your-storagebox.de:23): " sb
    read -r -p "remote path [/homeos]: " path; path="${path:-/homeos}"
    cat >>"$ENV" <<EOF
RESTIC_REPOSITORY_OFFSITE=sftp:${sb}:${path}
EOF
    ;;
  4)
    read -r -p "S3 endpoint (e.g. https://s3.eu-central-1.amazonaws.com): " ep
    read -r -p "bucket: " bucket
    read -r -p "AWS_ACCESS_KEY_ID: " ak
    read -r -s -p "AWS_SECRET_ACCESS_KEY: " sk; echo
    cat >>"$ENV" <<EOF
RESTIC_REPOSITORY_OFFSITE=s3:${ep}/${bucket}
AWS_ACCESS_KEY_ID=${ak}
AWS_SECRET_ACCESS_KEY=${sk}
EOF
    ;;
  5)
    apt-get install -y rclone || true
    echo "run: rclone config — then re-run this installer w/ --reconfigure"
    read -r -p "rclone remote name: " rem
    read -r -p "remote path: " p
    echo "RESTIC_REPOSITORY_OFFSITE=rclone:${rem}:${p}" >> "$ENV"
    ;;
  *) echo "invalid"; exit 1 ;;
esac

read -r -s -p "RESTIC_PASSWORD (offsite): " pw; echo
echo "RESTIC_PASSWORD_OFFSITE=${pw}" >> "$ENV"
chmod 600 "$ENV"

# Init repo
. "$ENV"
RESTIC_REPOSITORY="$RESTIC_REPOSITORY_OFFSITE" RESTIC_PASSWORD="$RESTIC_PASSWORD_OFFSITE" \
  restic init || echo "  (repo may already exist — OK)"

# Cron — runs after local backup
cat >/etc/cron.d/homeos-offsite-backup <<'CRON'
# offsite restic, daily 03:30 BRT (after local 02:30)
30 3 * * * root /usr/local/sbin/homeos-offsite-backup
CRON

cat >/usr/local/sbin/homeos-offsite-backup <<'SH'
#!/usr/bin/env bash
set -euo pipefail
. /etc/homeos/backup.env
RESTIC_REPOSITORY="$RESTIC_REPOSITORY_OFFSITE" \
RESTIC_PASSWORD="$RESTIC_PASSWORD_OFFSITE" \
  restic backup /srv /opt/stacks /home/admin --exclude-caches
RESTIC_REPOSITORY="$RESTIC_REPOSITORY_OFFSITE" \
RESTIC_PASSWORD="$RESTIC_PASSWORD_OFFSITE" \
  restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
SH
chmod +x /usr/local/sbin/homeos-offsite-backup

echo "offsite backup configured. cron at 03:30 BRT daily."
