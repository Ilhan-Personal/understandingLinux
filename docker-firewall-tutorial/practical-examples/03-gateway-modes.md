# Docker Gateway Modes

## What are Gateway Modes?

Gateway modes control how Docker handles Network Address Translation (NAT) and port publishing for bridge networks. Understanding these modes is crucial for implementing direct routing and advanced networking scenarios.

## The Four Gateway Modes

### 1. **NAT Mode** (Default)
- **Behavior**: Full NAT with masquerading
- **Access**: Only via published host ports
- **Outgoing**: Uses host IP address
- **Security**: Most restrictive

### 2. **NAT-Unprotected Mode** 
- **Behavior**: NAT without port filtering
- **Access**: Direct routing to all container ports
- **Outgoing**: Uses host IP address  
- **Security**: Less secure - all ports accessible

### 3. **Routed Mode**
- **Behavior**: No NAT, direct routing
- **Access**: Direct access to container IPs
- **Outgoing**: Uses container IP address
- **Security**: Container IPs exposed

### 4. **Isolated Mode**
- **Behavior**: No host connectivity
- **Access**: No external access
- **Outgoing**: Container-to-container only
- **Security**: Maximum isolation

## Practical Example 1: Routed Mode Setup

### Scenario
You want containers to use their real IP addresses for outgoing connections instead of the host IP.

### Implementation

```bash
# Create network with routed mode for IPv4
docker network create \
  --driver bridge \
  --subnet 192.0.2.0/24 \
  --ip-range 192.0.2.0/29 \
  -o com.docker.network.bridge.gateway_mode_ipv4=routed \
  routed-net
```

### Start Container
```bash
# Run container with published port
docker run -d --name web-routed \
  --network routed-net \
  --ip 192.0.2.100 \
  -p 8080:80 \
  nginx
```

### Key Differences

**With NAT mode (default):**
- Client connects to: `host:8080`
- Container sees: `client_ip → container:80`
- Outgoing traffic from: `host_ip`

**With routed mode:**
- Client connects to: `host:8080` OR `192.0.2.100:80` (direct)
- Container sees: `client_ip → container:80`
- Outgoing traffic from: `192.0.2.100` (container IP)

## Practical Example 2: Mixed IPv4/IPv6 Gateway Modes

### Scenario
Use NAT for IPv4 (compatibility) but routed mode for IPv6 (modern networking).

### Setup Network
```bash
docker network create \
  --ipv6 \
  --subnet 192.0.2.0/24 \
  --subnet 2001:db8::/64 \
  -o com.docker.network.bridge.gateway_mode_ipv4=nat \
  -o com.docker.network.bridge.gateway_mode_ipv6=routed \
  mixed-mode-net
```

### Run Container
```bash
docker run -d --name mixed-web \
  --network mixed-mode-net \
  --ip 192.0.2.10 \
  --ip6 2001:db8::10 \
  -p 8080:80 \
  nginx
```

### Result
- **IPv4**: Accessible via host:8080 (NAT)
- **IPv6**: Accessible via [2001:db8::10]:80 (direct routing)

## Practical Example 3: Trusted Host Interfaces

### Scenario
Allow direct routing only from specific network interfaces (VPN, internal networks).

### Setup
```bash
# Create network with trusted interfaces
docker network create \
  --subnet 192.0.2.0/24 \
  --ip-range 192.0.2.0/29 \
  -o com.docker.network.bridge.trusted_host_interfaces="vxlan.1:eth1" \
  -o com.docker.network.bridge.gateway_mode_ipv4=routed \
  trusted-net
```

### Understanding Trusted Interfaces
- `vxlan.1`: VPN interface
- `eth1`: Internal office network
- Traffic from these interfaces can access container IPs directly
- Traffic from other interfaces (like `eth0` - internet) cannot

## Practical Example 4: Isolated Network

### Scenario
Create a completely isolated network for sensitive processing.

### Setup
```bash
# Create isolated internal network
docker network create \
  --internal \
  --subnet 10.0.10.0/24 \
  -o com.docker.network.bridge.gateway_mode_ipv4=isolated \
  secret-net
```

### Run Containers
```bash
# Database container (isolated)
docker run -d --name secret-db \
  --network secret-net \
  --ip 10.0.10.10 \
  -e MYSQL_ROOT_PASSWORD=secret \
  mysql:5.7

# Processing container (isolated)  
docker run -d --name processor \
  --network secret-net \
  --ip 10.0.10.20 \
  alpine:latest sleep infinity
```

### Characteristics
- No host bridge IP assigned
- Containers can communicate with each other
- No external network access
- Host cannot access containers

## Testing Gateway Modes

### Test Script
```bash
#!/bin/bash

# Test connectivity for different gateway modes
test_connectivity() {
    local container_name="$1"
    local container_ip="$2"
    
    echo "Testing $container_name ($container_ip):"
    
    # Test host port access
    echo -n "  Host port access: "
    curl -s --connect-timeout 2 http://localhost:8080 >/dev/null && echo "✅" || echo "❌"
    
    # Test direct IP access (from host)
    echo -n "  Direct IP access: "
    curl -s --connect-timeout 2 http://$container_ip:80 >/dev/null && echo "✅" || echo "❌"
    
    # Test outgoing connection source
    echo -n "  Outgoing IP check: "
    docker exec $container_name curl -s http://httpbin.org/ip 2>/dev/null | grep -o '"origin":"[^"]*"' || echo "Failed"
    
    echo
}

# Usage
test_connectivity "web-nat" "172.17.0.2"
test_connectivity "web-routed" "192.0.2.100"
```

## Troubleshooting Gateway Modes

### Check Current Mode
```bash
# Inspect network configuration
docker network inspect mynet | jq '.[0].Options'

# Look for gateway_mode settings
docker network inspect mynet | grep -i gateway
```

### Common Issues

#### 1. Direct routing not working
**Problem**: Can't access container IP directly
**Solution**: Check routing table and host interfaces

```bash
# Check routes to container subnet
ip route show | grep 192.0.2.0/24

# Add route if missing (temporary)
sudo ip route add 192.0.2.0/24 via docker_host_ip
```

#### 2. Wrong outgoing IP in routed mode
**Problem**: Containers still use host IP for outgoing connections
**Solution**: Verify gateway mode is set correctly

```bash
# Check if mode is actually applied
docker network inspect mynet | grep gateway_mode_ipv4
```

#### 3. Trusted interfaces not working
**Problem**: Can't access containers from trusted interfaces
**Solution**: Verify interface names and iptables rules

```bash
# Check interface names
ip link show

# Check iptables rules for trusted interfaces
sudo iptables -L DOCKER-USER -v -n
```

## Advanced Configurations

### Multi-Gateway Setup
```bash
# Different gateway modes for different purposes
docker network create \
  --ipv6 \
  --subnet 192.0.2.0/24 \
  --subnet 2001:db8:1111::/64 \
  -o com.docker.network.bridge.gateway_mode_ipv4=nat \
  -o com.docker.network.bridge.gateway_mode_ipv6=routed \
  -o com.docker.network.bridge.trusted_host_interfaces="eth1:vpn0" \
  advanced-net
```

### Custom Host Binding
```bash
# Bind to specific host interfaces only
docker network create \
  --subnet 172.20.0.0/16 \
  -o "com.docker.network.bridge.host_binding_ipv4=10.0.1.100" \
  custom-bind-net
```

## Security Implications

### NAT Mode (Most Secure)
- ✅ Container IPs hidden from external networks
- ✅ Only published ports accessible
- ✅ Host IP used for outgoing connections

### Routed Mode (Moderate Security)
- ⚠️ Container IPs exposed to external networks
- ⚠️ All published ports accessible directly
- ⚠️ Container IP visible in logs/connections

### NAT-Unprotected Mode (Least Secure)
- ❌ All container ports accessible
- ❌ No port filtering
- ❌ Easy lateral movement

### Isolated Mode (Maximum Security)
- ✅ Complete network isolation
- ✅ No external connectivity
- ✅ Only container-to-container communication

## Best Practices

1. **Use NAT mode by default** - most secure and compatible
2. **Use routed mode for IPv6** - modern networking standard
3. **Test thoroughly** - gateway modes affect connectivity significantly
4. **Document your choice** - future administrators need to understand the setup
5. **Monitor outgoing connections** - verify containers use expected source IPs
6. **Combine with firewall rules** - gateway modes don't replace proper firewalling

---
**💡 Pro Tip**: Gateway modes are powerful but can complicate networking. Start with defaults and only change when you have specific requirements! 
