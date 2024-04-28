#!/bin/bash

# Create two network namespaces
ip netns add ns1
ip netns add ns2

# Create a veth pair
ip link add veth0 type veth peer name veth1

# Move one end of the veth pair into ns1
ip link set veth0 netns ns1

# Move the other end of the veth pair into ns2
ip link set veth1 netns ns2

# Configure IP addresses for the veth interfaces
ip netns exec ns1 ip addr add 192.168.1.1/24 dev veth0
ip netns exec ns2 ip addr add 192.168.2.1/24 dev veth1

# Bring up the veth interfaces
ip netns exec ns1 ip link set dev veth0 up
ip netns exec ns2 ip link set dev veth1 up

# Enable IP forwarding between the namespaces
ip netns exec ns1 sysctl -w net.ipv4.ip_forward=1

ip netns exec ns2 sysctl -w net.ipv4.ip_forward=1

# Add a route in ns1 to reach ns2
ip netns exec ns1 ip route add 192.168.2.0/24 via 192.168.1.1 dev veth0

# Add a route in ns2 to reach ns1
ip netns exec ns2 ip route add 192.168.1.0/24 via 192.168.2.1 dev veth1

# Test connectivity between the namespaces
ip netns exec ns1 ping -c 3 192.168.2.1


