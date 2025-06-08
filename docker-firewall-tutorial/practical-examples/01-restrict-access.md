# Restricting External Access to Containers

## Scenario: Web Server Security

You're running a web server container that should only be accessible from your office network (192.168.1.0/24), not from the entire internet.

## Problem

By default, published Docker ports are accessible from ANY external IP address:

```bash
# This exposes port 80 to the ENTIRE internet!
docker run -d -p 8080:80 nginx
```

## Solution 1: Block All Except Allowed Network

### Step 1: Start a test container
```bash
docker run -d --name web-server -p 8080:80 nginx
```

### Step 2: Add restrictive rule
```bash
# Block all traffic except from office network
sudo iptables -I DOCKER-USER -i eth0 ! -s 192.168.1.0/24 -j DROP
```

### Step 3: Allow established connections
```bash
# Allow responses to existing connections (IMPORTANT!)
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Test the Configuration
```bash
# From office network (192.168.1.x) - should work
curl http://your-docker-host:8080

# From external network - should fail
curl http://your-docker-host:8080
```

## Solution 2: Allow Specific IP Addresses

### Single IP Address
```bash
# Only allow access from specific IP
sudo iptables -I DOCKER-USER -i eth0 ! -s 203.0.113.100 -j DROP
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Multiple IP Addresses (using IP range)
```bash
# Allow access from IP range 203.0.113.100-103
sudo iptables -I DOCKER-USER -m iprange -i eth0 ! --src-range 203.0.113.100-203.0.113.103 -j DROP
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## Solution 3: Port-Specific Restrictions

### Restrict specific ports only
```bash
# Block external access to port 8080 only
sudo iptables -I DOCKER-USER -i eth0 -p tcp --dport 8080 ! -s 192.168.1.0/24 -j DROP
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## Advanced: Multiple Network Interfaces

If your Docker host has multiple network interfaces:

```bash
# eth0 = external interface (internet)
# eth1 = internal interface (office network)

# Block external access via eth0, allow internal via eth1
sudo iptables -I DOCKER-USER -i eth0 ! -s 192.168.1.0/24 -j DROP
sudo iptables -I DOCKER-USER -i eth1 -j ACCEPT
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## Understanding the Rules

### Rule Breakdown
```bash
iptables -I DOCKER-USER -i eth0 ! -s 192.168.1.0/24 -j DROP
```

- `-I DOCKER-USER`: Insert at top of DOCKER-USER chain
- `-i eth0`: Match packets coming from eth0 interface
- `! -s 192.168.1.0/24`: NOT from source network 192.168.1.0/24
- `-j DROP`: Drop (reject) the packet

### Why RELATED,ESTABLISHED is Important
```bash
iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
```

This rule allows:
- **ESTABLISHED**: Return traffic for connections already started
- **RELATED**: Related traffic (like FTP data connections)

Without this rule, even allowed clients can't get responses!

## Verification Commands

### Check your rules
```bash
# View DOCKER-USER chain
sudo iptables -L DOCKER-USER -n -v --line-numbers

# Check rule hit counts
sudo iptables -L DOCKER-USER -n -v
```

### Test connectivity
```bash
# Test from allowed network
curl -v http://docker-host:8080

# Test from blocked network (should timeout/fail)
curl -v --connect-timeout 5 http://docker-host:8080
```

## Cleanup

### Remove test container
```bash
docker stop web-server
docker rm web-server
```

### Remove iptables rules
```bash
# List rules with line numbers
sudo iptables -L DOCKER-USER -n --line-numbers

# Delete specific rule (replace X with line number)
sudo iptables -D DOCKER-USER X
```

## Common Issues & Solutions

### Issue: Can't access from allowed IPs
**Solution**: Check that ESTABLISHED,RELATED rule comes BEFORE DROP rules

### Issue: Rules don't persist after reboot
**Solution**: Use `iptables-persistent` package or save rules manually

### Issue: Still accessible from blocked IPs
**Solution**: Verify interface name (`ip link show`) and rule order

---
**⚠️ Warning**: Always test rules carefully! You can lock yourself out of the system. 
