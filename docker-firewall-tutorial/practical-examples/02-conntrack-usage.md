# Using Conntrack with Docker

## What is Conntrack?

Conntrack (Connection Tracking) is an iptables extension that tracks the state of network connections. It's essential when you need to match packets based on their **original** destination before Docker's NAT transforms them.

## The Problem: NAT Changes Packet Headers

When packets reach Docker's DOCKER-USER chain, they've already been through DNAT (Destination Network Address Translation). This means:

- **Original request**: `client:12345 → host:8080`
- **After DNAT**: `client:12345 → container:80`

Your iptables rules see the **transformed** packet, not the original!

## When to Use Conntrack

Use conntrack when you need to:
- Match against original destination IP/port
- Filter based on the client's original request
- Implement rules that depend on the "real" destination

## Basic Conntrack Rules

### Allow Established Connections
```bash
# Allow return traffic for existing connections
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

### Match Original Destination
```bash
# Allow traffic originally destined for host:8080
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdst 198.51.100.2 --ctorigdstport 8080 -j ACCEPT
```

## Practical Example: Multi-Service Container Host

### Scenario Setup
You have a Docker host (`198.51.100.2`) running multiple services:
- Web server on port 8080 → container port 80
- API server on port 8081 → container port 3000  
- Database on port 5432 → container port 5432

```bash
# Start test containers
docker run -d --name web -p 8080:80 nginx
docker run -d --name api -p 8081:3000 node:alpine
docker run -d --name db -p 5432:5432 postgres
```

### Security Requirements
- Web server: Allow from anywhere
- API server: Only from office network (192.168.1.0/24)
- Database: Only from localhost

### Implementation with Conntrack

```bash
# 1. Allow established connections (must be first!)
sudo iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 2. Allow web server from anywhere (port 8080)
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdst 198.51.100.2 --ctorigdstport 8080 -j ACCEPT

# 3. Allow API server only from office network (port 8081)
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdst 198.51.100.2 --ctorigdstport 8081 -s 192.168.1.0/24 -j ACCEPT

# 4. Allow database only from localhost (port 5432)
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdst 198.51.100.2 --ctorigdstport 5432 -s 127.0.0.1 -j ACCEPT

# 5. Block everything else
sudo iptables -A DOCKER-USER -j DROP
```

## Advanced Conntrack Examples

### Source Port Matching
```bash
# Allow connections from specific source port range
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdst 198.51.100.2 --ctorigdstport 8080 --ctorigsrcport 1024:65535 -j ACCEPT
```

### Multiple Destination Ports
```bash
# Allow traffic to multiple ports on the same host
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdst 198.51.100.2 -m multiport --ctorigdstports 8080,8081,8082 -j ACCEPT
```

### Connection State Combinations
```bash
# Allow new connections from trusted network, established from anywhere
sudo iptables -I DOCKER-USER -m conntrack --ctstate NEW -s 192.168.1.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

## Conntrack vs Regular Rules

### Without Conntrack (Won't Work as Expected)
```bash
# This matches the container IP/port, not what the client requested!
sudo iptables -I DOCKER-USER -p tcp --dport 80 -s 192.168.1.0/24 -j ACCEPT
```

### With Conntrack (Correct)
```bash
# This matches the original request from the client
sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdstport 8080 -s 192.168.1.0/24 -j ACCEPT
```

## Performance Considerations

### Conntrack Impact
- **CPU overhead**: Conntrack adds processing overhead
- **Memory usage**: Tracks connection state in memory
- **Connection limits**: Default limit is 65536 connections

### Optimize Conntrack
```bash
# Increase connection tracking table size
echo 131072 > /proc/sys/net/netfilter/nf_conntrack_max

# Reduce connection timeout for faster cleanup
echo 120 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established
```

## Debugging Conntrack

### View Connection Tracking Table
```bash
# Show all tracked connections
cat /proc/net/nf_conntrack

# Show connections for specific port
cat /proc/net/nf_conntrack | grep :8080
```

### Monitor Conntrack Events
```bash
# Install conntrack tools
sudo apt-get install conntrack

# Monitor connection events in real-time
sudo conntrack -E

# Show specific connections
sudo conntrack -L -p tcp --dport 8080
```

## Testing Your Rules

### Test Script
```bash
#!/bin/bash
echo "Testing web server (should work from anywhere)..."
curl -s http://198.51.100.2:8080 && echo "✅ Web server accessible"

echo "Testing API server (should work from office network only)..."
curl -s http://198.51.100.2:8081 && echo "✅ API server accessible"

echo "Testing database (should work from localhost only)..."
nc -z 127.0.0.1 5432 && echo "✅ Database accessible"
```

## Common Pitfalls

### 1. Wrong Rule Order
```bash
# ❌ Wrong: DROP rule before ACCEPT rules
sudo iptables -A DOCKER-USER -j DROP
sudo iptables -A DOCKER-USER -m conntrack --ctorigdstport 8080 -j ACCEPT

# ✅ Correct: ACCEPT rules before DROP rule
sudo iptables -I DOCKER-USER -m conntrack --ctorigdstport 8080 -j ACCEPT
sudo iptables -A DOCKER-USER -j DROP
```

### 2. Forgetting ESTABLISHED Connections
```bash
# ❌ Wrong: No return traffic allowed
sudo iptables -I DOCKER-USER -m conntrack --ctorigdstport 8080 -j ACCEPT

# ✅ Correct: Allow return traffic
sudo iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -I DOCKER-USER -m conntrack --ctorigdstport 8080 -j ACCEPT
```

## Cleanup

```bash
# Remove test containers
docker stop web api db
docker rm web api db

# Clear DOCKER-USER rules
sudo iptables -F DOCKER-USER
```

---
**⚠️ Performance Warning**: Use conntrack judiciously - it can impact performance on high-traffic systems! 
