# Common Docker Firewall Scenarios

## Scenario 1: Web Server with Admin Panel

### The Setup
- Public web server (port 80) - accessible from internet
- Admin panel (port 8080) - only from office network
- Database (port 3306) - only from localhost

### Implementation
```bash
# Start containers
docker run -d --name web-public -p 80:80 nginx
docker run -d --name web-admin -p 8080:80 nginx  
docker run -d --name database -p 3306:3306 mysql

# Security rules
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 80 -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 8080 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 3306 -s 127.0.0.1 -j ACCEPT
sudo iptables -A DOCKER-USER -j DROP
```

### Why This Works
- Port 80: Open to everyone (public website)
- Port 8080: Only office network can access admin panel
- Port 3306: Only localhost can connect to database
- Everything else: Blocked by default

---

## Scenario 2: Development Environment

### The Challenge
Developers need access to multiple services, but external access should be blocked during development.

### Solution: Interface-Based Rules
```bash
# Allow access from internal network interface (eth1)
sudo iptables -I DOCKER-USER -i eth1 -j ACCEPT

# Block access from external interface (eth0) 
sudo iptables -I DOCKER-USER -i eth0 -j DROP

# Always allow established connections first
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Benefits
- Developers on internal network: Full access
- External users: Completely blocked
- Simple to manage: One rule per interface

---

## Scenario 3: Microservices with API Gateway

### Architecture
```
Internet → API Gateway (port 443) → Internal Services
              ↓
    Service A (8001), Service B (8002), Service C (8003)
```

### Requirements
- Only API Gateway accessible from internet
- Internal services only accessible from API Gateway container
- Inter-service communication allowed

### Implementation
```bash
# Get API Gateway container IP
GATEWAY_IP=$(docker inspect api-gateway --format '{{.NetworkSettings.IPAddress}}')

# Security rules
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow public access to API Gateway
sudo iptables -I DOCKER-USER -p tcp --dport 443 -j ACCEPT

# Allow API Gateway to access internal services
sudo iptables -I DOCKER-USER -p tcp -m multiport --dports 8001,8002,8003 -s $GATEWAY_IP -j ACCEPT

# Block direct access to internal services
sudo iptables -A DOCKER-USER -p tcp -m multiport --dports 8001,8002,8003 -j DROP

# Block everything else
sudo iptables -A DOCKER-USER -j DROP
```

---

## Scenario 4: Staging vs Production

### The Problem
Same Docker setup used for staging and production, but different security requirements.

### Solution: Environment-Based Configuration

#### Production Configuration
```bash
# Strict production rules
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 443 -j ACCEPT  # HTTPS only
sudo iptables -A DOCKER-USER -j DROP  # Block everything else
```

#### Staging Configuration
```bash
# More relaxed staging rules
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I DOCKER-USER -s 192.168.1.0/24 -j ACCEPT  # Office network
sudo iptables -I DOCKER-USER -s 10.0.0.0/8 -j ACCEPT     # VPN network
sudo iptables -A DOCKER-USER -j DROP
```

---

## Scenario 5: Container-to-Container Communication

### Challenge
Allow containers in the same application to communicate, but block access from other applications.

### Solution: Docker Network Isolation + Firewall
```bash
# Create application-specific network
docker network create app1-network
docker network create app2-network

# Start containers in their networks
docker run -d --network app1-network --name app1-web -p 8080:80 nginx
docker run -d --network app1-network --name app1-db mysql

docker run -d --network app2-network --name app2-web -p 8081:80 nginx
docker run -d --network app2-network --name app2-db mysql

# Firewall rules (networks already provide isolation)
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 8080 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 8081 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A DOCKER-USER -j DROP
```

---

## Scenario 6: Time-Based Access Control

### Use Case
Allow access to admin services only during business hours.

### Implementation
```bash
# Allow admin access during business hours (9 AM - 6 PM, Mon-Fri)
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 8080 \
  -m time --timestart 09:00 --timestop 18:00 --weekdays Mon,Tue,Wed,Thu,Fri \
  -j ACCEPT

# Block admin access outside business hours  
sudo iptables -A DOCKER-USER -p tcp --dport 8080 -j DROP

# Allow public services 24/7
sudo iptables -I DOCKER-USER -p tcp --dport 80 -j ACCEPT
```

---

## Scenario 7: Rate Limiting with IPTables

### Problem
Prevent DoS attacks and abuse of container services.

### Solution: Connection Rate Limiting
```bash
# Allow established connections
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT

# Rate limit new connections (max 10 per minute per IP)
sudo iptables -I DOCKER-USER -p tcp --dport 80 \
  -m state --state NEW \
  -m recent --set --name web_limit

sudo iptables -I DOCKER-USER -p tcp --dport 80 \
  -m state --state NEW \
  -m recent --update --seconds 60 --hitcount 10 --name web_limit \
  -j DROP

# Allow normal web traffic
sudo iptables -I DOCKER-USER -p tcp --dport 80 -j ACCEPT
```

---

## Scenario 8: Geographic Restrictions

### Use Case
Block traffic from certain countries or regions.

### Solution: GeoIP Filtering (requires xtables-addons)
```bash
# Install GeoIP database (Ubuntu/Debian)
sudo apt-get install xtables-addons-common

# Block traffic from specific countries
sudo iptables -I DOCKER-USER -m geoip --src-cc CN,RU -j DROP

# Allow established connections
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow web traffic from allowed countries
sudo iptables -I DOCKER-USER -p tcp --dport 80 -j ACCEPT
```

---

## Scenario 9: VPN-Only Access

### Requirement
Critical services only accessible via VPN.

### Implementation
```bash
# Identify VPN interface and subnet
VPN_INTERFACE="tun0"
VPN_SUBNET="10.8.0.0/24"

# Allow VPN traffic
sudo iptables -I DOCKER-USER -i $VPN_INTERFACE -j ACCEPT
sudo iptables -I DOCKER-USER -s $VPN_SUBNET -j ACCEPT

# Allow established connections
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT

# Block everything else
sudo iptables -A DOCKER-USER -j DROP
```

---

## Scenario 10: Logging and Monitoring

### Goal
Log blocked connection attempts for security monitoring.

### Solution: Logging Rules
```bash
# Log dropped packets (before DROP rule)
sudo iptables -I DOCKER-USER -j LOG --log-prefix "DOCKER-FIREWALL-DROP: " --log-level 4

# Your regular rules
sudo iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 80 -s 192.168.1.0/24 -j ACCEPT

# Final DROP rule
sudo iptables -A DOCKER-USER -j DROP
```

### View Logs
```bash
# View firewall logs
sudo tail -f /var/log/syslog | grep "DOCKER-FIREWALL-DROP"

# Or use journalctl
sudo journalctl -f | grep "DOCKER-FIREWALL-DROP"
```

---

## Quick Reference: Common Rule Patterns

### Allow Specific Network
```bash
sudo iptables -I DOCKER-USER -s 192.168.1.0/24 -j ACCEPT
```

### Allow Specific Port from Anywhere
```bash
sudo iptables -I DOCKER-USER -p tcp --dport 80 -j ACCEPT
```

### Allow Specific Port from Specific Network
```bash
sudo iptables -I DOCKER-USER -p tcp --dport 8080 -s 192.168.1.0/24 -j ACCEPT
```

### Block Specific IP
```bash
sudo iptables -I DOCKER-USER -s 192.168.1.100 -j DROP
```

### Allow Multiple Ports
```bash
sudo iptables -I DOCKER-USER -p tcp -m multiport --dports 80,443,8080 -j ACCEPT
```

### Time-Based Access
```bash
sudo iptables -I DOCKER-USER -p tcp --dport 22 \
  -m time --timestart 09:00 --timestop 17:00 -j ACCEPT
```

---

**💡 Pro Tip**: Always test your rules in a safe environment first. One wrong rule can lock you out of your system! 
