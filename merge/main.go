package main

// shamelessly copied from <https://github.com/zhanhb/cidr-merger>
// thank you!

import (
	"bufio"
	"fmt"
	"net"
	"os"
)

var privateCIDRs = []string{
	"0.0.0.0/8",
	"10.0.0.0/8",
	"100.64.0.0/10",
	"127.0.0.0/8",
	"169.254.0.0/16",
	"172.16.0.0/12",
	"192.0.0.0/24",
	"192.0.2.0/24",
	"192.88.99.0/24",
	"192.168.0.0/16",
	"198.18.0.0/15",
	"198.51.100.0/24",
	"203.0.113.0/24",
	"224.0.0.0/4",
	"240.0.0.0/4",
	"255.255.255.255/32",
	"::1/128",
	"fc00::/7",
	"fe80::/10",
}

func parse(text string) (IRange, error) {
	if _, network, err := net.ParseCIDR(text); err == nil {
		// if network overlaps with private range
		for _, cidr := range privateCIDRs {
			if _, private, err := net.ParseCIDR(cidr); err == nil {
				if private.Contains(network.IP) {
					return nil, fmt.Errorf("[merge] %s overlaps within private range %s, ignoring", text, cidr)
				}
			}
		}
		return IpNetWrapper{network}, nil
	} else {
		return nil, err
	}
}

func main() {
	var input = bufio.NewScanner(os.Stdin)

	input.Split(bufio.ScanWords)
	var arr []IRange
	for input.Scan() {
		if text := input.Text(); text != "" {
			if maybe, err := parse(text); err != nil {
				fmt.Fprintln(os.Stderr, err)
			} else {
				arr = append(arr, maybe)
			}
		}
		if err := input.Err(); err != nil {
			panic(err)
		}
	}
	result := sortAndMerge(arr)

	writer := bufio.NewWriter(os.Stdout)
	for _, r := range result {
		for _, cidr := range r.ToIpNets() {
			fmt.Fprintln(writer, IpNetWrapper{cidr})
		}
	}
	if err := writer.Flush(); err != nil {
		panic(err)
	}
}
