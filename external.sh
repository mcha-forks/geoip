#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit

# [ HELPERS
# cursor_rewind - Move cursor up and clear line
cursor_rewind() {
	printf '\033[F\033[2K' >&2
}

# furl - Fetch URL, wraps around cURL
furl() {
	curl -L --fail --progress-bar "${@}"
	cursor_rewind
}

###### msg formatting excerpted from libmakepkg #####
# SPDX-License-Identifier: GPL-2.0-or-later
ALL_OFF="\e[0m"
BOLD="\e[1m"
BLUE="${BOLD}\e[34m"
GREEN="${BOLD}\e[32m"
RED="${BOLD}\e[31m"

msg() {
	local mesg=$1
	shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

msg2() {
	local mesg=$1
	shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

error() {
	local mesg=$1
	shift
	printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
	cleanup
	exit 1
}

##### end #####
# ] END HELPERS

# [ INIT
msg "Preparing..."
if [[ -d "data" && -w "data" ]]; then
	msg2 "Cleaning up old data..."
	rm -rv "data"
fi || error "Failed to clean up old data"

mkdir -p "data"
# ] END INIT
fetch_data() {
	# [ ASN
	msg "[asn] retrieving IP blocks from RIPE"
	local line
	while read -r line; do
		local filename
		local file
		filename=$(echo "${line}" | cut -d',' -f1)
		IFS='|' read -r -a asns <<<"$(echo "${line}" | cut -d',' -f2)"
		file=data/${filename}

		for asn in "${asns[@]}"; do
			msg2 "fetching ${asn}"
			furl "https://stat.ripe.net/data/ris-prefixes/data.json?list_prefixes=true&types=o&resource=${asn}" |
				jq --raw-output '.data.prefixes | .v4, .v6 | .originating[]' |
				sort -u >>"${file}"
			cursor_rewind
		done
		msg2 "${filename}: $(wc -l "${file}" | cut -d' ' -f1) records out"
	done <"asn.csv"
	unset line

	msg "[asn] appending extra data"
	furl "https://www.cloudflare.com/ips-v4" "https://www.cloudflare.com/ips-v6" |
		grep "/" >>"data/cloudflare"
	furl "https://api.fastly.com/public-ip-list" |
		jq --raw-output '.addresses[],.ipv6_addresses[]' >>"data/fastly"
	furl "https://ip-ranges.amazonaws.com/ip-ranges.json" |
		jq --raw-output '.prefixes[],.ipv6_prefixes[] | select(.service == "CLOUDFRONT") | .ip_prefix,.ipv6_prefix' |
		grep "/" >>"data/cloudfront"
	# ] END ASN

	msg "[game] retrieving rules from netch repository"

	local game
	game="$(
		furl "https://github.com/netchx/netch/archive/refs/heads/main.tar.gz" |
			tar xOzf - 'netch-main/Storage/mode/TUNTAP/*.txt' -X "game-ignore.txt" |
			sed 's/#.*$//;/^$/d'
	)"

	read -r -a game_pick <"game-pick.txt"
	msg2 "picking ${#game_pick[@]} extra rule(s)"
	game+="$(furl "${game_pick[@]}" | sed 's/#.*$//')"

	go run ./merge <<<"${game}" >"data/game"
	msg2 "$(wc -l data/game | cut -d' ' -f1) records out"
}

fetch_data
