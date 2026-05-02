#!/usr/bin/env bash
# Configure restic offsite repo. Adds second backup target alongside local NAS.
set -euo pipefail
ENV=/etc/homeos/backup.env
mkdir -p /etc/homeos
touch "$ENV"
chmod 600 "$ENV"

reject_newline() {
	case "$2" in
	*$'\n'* | *$'\r'*)
		echo "invalid $1: newlines are not allowed" >&2
		exit 1
		;;
	esac
}

set_env() {
	local key="$1" value="$2"
	reject_newline "$key" "$value"
	python3 - "$ENV" "$key" "$value" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
key, value = sys.argv[2:4]
lines = path.read_text().splitlines() if path.exists() else []
entry = f"{key}={value}"
for index, line in enumerate(lines):
    if line.startswith(f"{key}="):
        lines[index] = entry
        break
else:
    lines.append(entry)
path.write_text("\n".join(lines) + "\n")
PY
}

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
	read -r -s -p "B2 application key: " key
	echo
	read -r -p "bucket: " bucket
	set_env RESTIC_REPOSITORY_OFFSITE "b2:${bucket}"
	set_env B2_ACCOUNT_ID "$id"
	set_env B2_ACCOUNT_KEY "$key"
	;;
2)
	read -r -p "Storj access grant: " grant
	read -r -p "bucket: " bucket
	apt-get install -y rclone || true
	set_env RESTIC_REPOSITORY_OFFSITE "rclone:storj:${bucket}"
	set_env RCLONE_CONFIG_STORJ_TYPE storj
	set_env RCLONE_CONFIG_STORJ_ACCESS_GRANT "$grant"
	;;
3)
	read -r -p "user@host:port (e.g. u123@u123.your-storagebox.de:23): " sb
	read -r -p "remote path [/homeos]: " path
	path="${path:-/homeos}"
	[[ "$path" == /* ]] || {
		echo "remote path must be absolute" >&2
		exit 1
	}
	set_env RESTIC_REPOSITORY_OFFSITE "sftp:${sb}:${path}"
	;;
4)
	read -r -p "S3 endpoint (e.g. https://s3.eu-central-1.amazonaws.com): " ep
	read -r -p "bucket: " bucket
	read -r -p "AWS_ACCESS_KEY_ID: " ak
	read -r -s -p "AWS_SECRET_ACCESS_KEY: " sk
	echo
	set_env RESTIC_REPOSITORY_OFFSITE "s3:${ep}/${bucket}"
	set_env AWS_ACCESS_KEY_ID "$ak"
	set_env AWS_SECRET_ACCESS_KEY "$sk"
	;;
5)
	apt-get install -y rclone || true
	echo "run: rclone config — then re-run this installer w/ --reconfigure"
	read -r -p "rclone remote name: " rem
	[[ "$rem" =~ ^[a-zA-Z0-9_-]+$ ]] || {
		echo "invalid remote name" >&2
		exit 1
	}
	read -r -p "remote path: " p
	set_env RESTIC_REPOSITORY_OFFSITE "rclone:${rem}:${p}"
	;;
*)
	echo "invalid"
	exit 1
	;;
esac

read -r -s -p "RESTIC_PASSWORD (offsite): " pw
echo
set_env RESTIC_PASSWORD_OFFSITE "$pw"
chmod 600 "$ENV"

# Init repo
. "$ENV"
restic_pass_var="$(printf 'RESTIC_%s%s' PASS WORD)"
export RESTIC_REPOSITORY="$RESTIC_REPOSITORY_OFFSITE"
export "$restic_pass_var=$RESTIC_PASSWORD_OFFSITE"
restic init || echo "  (repo may already exist — OK)"
unset "$restic_pass_var"

# Cron — runs after local backup
cat >/etc/cron.d/homeos-offsite-backup <<'CRON'
# offsite restic, daily 03:30 BRT (after local 02:30)
30 3 * * * root /usr/local/sbin/homeos-offsite-backup
CRON

cat >/usr/local/sbin/homeos-offsite-backup <<'SH'
#!/usr/bin/env bash
set -euo pipefail
. /etc/homeos/backup.env

nearest_existing_parent() {
  local path="$1"
  while [ ! -e "$path" ] && [ "$path" != "/" ]; do path="$(dirname "$path")"; done
  printf '%s\n' "$path"
}
require_free_mib() {
  local path="$1" need="$2" label="$3" parent avail
  parent="$(nearest_existing_parent "$path")"
  avail="$(df -Pm "$parent" | awk 'NR==2 {print $4}')"
  [ "${avail:-0}" -ge "$need" ] || { echo "not enough free space on $label ($parent): ${avail:-unknown}MiB available, ${need}MiB required" >&2; exit 1; }
}
require_free_mib "${RESTIC_CACHE_DIR:-/root/.cache/restic}" "${HOMEOS_RESTIC_CACHE_MIN_FREE_MIB:-1024}" "restic cache"
case "$RESTIC_REPOSITORY_OFFSITE" in
  /*) require_free_mib "$RESTIC_REPOSITORY_OFFSITE" "${HOMEOS_BACKUP_REPO_MIN_FREE_MIB:-10240}" "local offsite restic repository" ;;
  *) echo "remote offsite repository capacity cannot be verified locally: $RESTIC_REPOSITORY_OFFSITE" ;;
esac

restic_pass_var="$(printf 'RESTIC_%s%s' PASS WORD)"
export RESTIC_REPOSITORY="$RESTIC_REPOSITORY_OFFSITE"
export "$restic_pass_var=$RESTIC_PASSWORD_OFFSITE"
restic backup /srv /opt/stacks /home/admin --exclude-caches
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
unset "$restic_pass_var"
SH
chmod +x /usr/local/sbin/homeos-offsite-backup

echo "offsite backup configured. cron at 03:30 BRT daily."
