#!/usr/bin/env bash

rm -rf .tmp
mkdir -p .tmp data

input="asn.csv"

while IFS= read -r line; do
  filename=$(echo ${line} | awk -F ',' '{print $1}')
  IFS='|' read -r -a asns <<<$(echo ${line} | awk -F ',' '{print $2}')
  file="data/${filename}"

  rm -f ${file} && touch ${file}
  i=1
  for asn in ${asns[@]}; do
    echo "[asn] (${i}/${#asns[@]}) pulling ${filename} (${asn})"
    url="https://stat.ripe.net/data/ris-prefixes/data.json?list_prefixes=true&types=o&resource=${asn}"
    curl -L --progress-bar ${url} -o .tmp/${filename}-${asn}.txt \
      -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'
    jq --raw-output '.data.prefixes.v4.originating[]' .tmp/${filename}-${asn}.txt | sort -u >>${file}
    jq --raw-output '.data.prefixes.v6.originating[]' .tmp/${filename}-${asn}.txt | sort -u >>${file}
    printf '\033[F\033[2K\033[F\033[2K'
    i=$((i+1))
  done
  echo "[asn] ${filename} $(wc -l ${file} | cut -d' ' -f1) records out"
done <${input}

echo "[asn] appending extra data"
curl -L --progress-bar https://www.cloudflare.com/ips-v4 | grep "/" >> data/cloudflare
curl -L --progress-bar https://www.cloudflare.com/ips-v6 | grep "/" >> data/cloudflare
curl -L --progress-bar https://api.fastly.com/public-ip-list | jq --raw-output '.addresses[],.ipv6_addresses[]' >> data/fastly
curl -L --progress-bar https://ip-ranges.amazonaws.com/ip-ranges.json | jq --raw-output '.prefixes[],.ipv6_prefixes[] | select(.service == "CLOUDFRONT") | .ip_prefix,.ipv6_prefix' | grep "/" >> data/cloudfront

echo "[game] retrieving rules from netch repository"

svn co -q https://github.com/netchx/netch/trunk/Storage/mode/TUNTAP/ .tmp/game
rm -rf .tmp/game/.svn

printf '\033[F\033[2K'

echo "[game] retrieved $(ls -1 .tmp/game/*.txt | wc -l | cut -d' ' -f1) rules"

file="data/game"
rm -f ${file} && touch ${file}

input="game-ignore.txt"

while read -r line; do
  echo "[game] ignoring ${line}"
  rm ".tmp/game/${line}"
done <${input}

input="game-pick.txt"

while read -r line; do
  echo "[game] picking ${line}"
  curl -L --progress-bar "${line}" \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36' >> .tmp/game/pick.txt
  printf '\033[F\033[2K'
done <${input}

rm -f data/game && touch data/game

cat .tmp/game/*.txt | grep -v '#' | go run ./merge >> data/game

echo "[game] $(wc -l data/game | cut -d' ' -f1) records out"
