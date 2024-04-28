#!/bin/bash
ip link delete veth0
ip link delete veth1
ip netns delete ns1
ip netns delete ns2
