# Lab 1: Basic Container Access Restrictions

## 🎯 Objective
Learn to restrict access to Docker containers using iptables rules in the INPUT chain.

## 🛠️ Prerequisites
- Docker installed and running (or Colima on Mac)
- Root/sudo access
- Basic understanding of iptables

## 📋 Lab Scenario

You're a DevOps engineer securing a Docker host that runs multiple services. You need to control access to published container ports using INPUT chain filtering.

## 🚀 Exercise 1: Basic Web Server Restriction

### Task
Block access to a web server container by dropping packets at the INPUT chain level.

### Steps

1. **Start a web server container**
   ```bash
   docker run -itd -p 8080:80 nginx
   ```

2. **Test initial access** (should work)
   ```bash
   curl http://localhost:8080
   ```

3. **Add INPUT rule to drop traffic to port 8080**
   ```bash
   sudo iptables -I INPUT -p tcp --dport 8080 -j DROP
   ```

4. **Test access** (should now fail)
   ```bash
   curl http://localhost:8080
   # This should timeout or be refused
   ```

5. **Remove the rule when done testing**
   ```bash
   sudo iptables -D INPUT -p tcp --dport 8080 -j DROP
   ```

### ✅ Verification
```bash
# Check your INPUT rules
sudo iptables -L INPUT -n -v

# The output should show the DROP rule for port 8080
# You should see packet counters increasing when you test
```

### 📝 Notes
- This approach works in environments like Colima where published container ports are processed through the INPUT chain
- The INPUT chain processes packets destined for the local host, including published Docker ports
- This is different from the DOCKER-USER chain approach, which processes forwarded traffic between containers

## 🚀 Exercise 2: Port-Specific Restrictions

### Task
Run multiple services with different access requirements using INPUT chain rules.

### Setup
```bash
# Web server - public access
docker run -d --name public-web -p 8080:80 nginx

# Admin panel - restricted access  
docker run -d --name admin-panel -p 8081:80 nginx

# Database - localhost only
docker run -d --name database -p 3306:3306 -e MYSQL_ROOT_PASSWORD=secret mysql:5.7
```

### Your Challenge
Create iptables INPUT rules to:
1. Allow public access to port 8080 (web server)
2. Allow only your network (192.168.1.0/24) to access port 8081 (admin panel)
3. Allow only localhost to access port 3306 (database)

### Solution Template
```bash
# First, allow established connections to avoid breaking existing traffic
sudo iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Rule for public web server (port 8080) - allow from anywhere
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT

# Rule for admin panel (port 8081) - allow from local network only
sudo iptables -I INPUT -p tcp --dport 8081 -s 192.168.1.0/24 -j ACCEPT

# Rule for database (port 3306) - allow from localhost only
sudo iptables -I INPUT -p tcp --dport 3306 -s 127.0.0.1 -j ACCEPT

# Drop all other traffic to these specific ports
sudo iptables -A INPUT -p tcp --dport 8081 -j DROP
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP
```

### 🧪 Test Your Solution
```bash
# Test web server (should work)
curl http://localhost:8080

# Test admin panel from localhost (should work if you're on local network)
curl http://localhost:8081

# Test database (should work)
mysql -h 127.0.0.1 -P 3306 -u root -psecret -e "SELECT 1"
```

## 🚀 Exercise 3: Interface-Based Restrictions

### Task
Configure different INPUT rules for different network interfaces.

### Scenario
Your Docker host has multiple network interfaces and you want to control access based on which interface traffic arrives on.

### Requirements
- Block external access via external interface
- Allow internal network access
- Always allow localhost access for management

### Your Solution
```bash
# Clear existing rules for our ports
sudo iptables -D INPUT -p tcp --dport 8082 -j DROP 2>/dev/null || true

# Allow localhost always
sudo iptables -I INPUT -i lo -j ACCEPT

# Allow from internal network interface (adjust interface name as needed)
sudo iptables -I INPUT -i eth1 -p tcp --dport 8082 -j ACCEPT

# Block from external interface
sudo iptables -I INPUT -i eth0 -p tcp --dport 8082 -j DROP
```

### 💡 Hints
- Use `-i eth0` to match external interface
- Use `-i eth1` to match internal interface  
- Use `-i lo` for loopback interface
- Remember rule order matters - more specific rules should come first!

## 🚀 Exercise 4: Time-Based Access (Advanced)

### Task
Allow access to a container only during business hours (9 AM - 5 PM) using INPUT rules.

### Setup
```bash
docker run -d --name business-app -p 8082:80 nginx
```

### Your Challenge
Create INPUT rules that only allow access during business hours using the `time` module.

### Solution
```bash
# Allow access during business hours (9 AM - 5 PM)
sudo iptables -I INPUT -p tcp --dport 8082 -m time --timestart 09:00 --timestop 17:00 -j ACCEPT

# Drop access outside business hours
sudo iptables -A INPUT -p tcp --dport 8082 -j DROP
```

### Test
```bash
# Test during business hours (should work)
curl http://localhost:8082

# Test outside business hours (should fail)
```

## 📊 Self-Assessment Questions

1. **What happens if you forget the ESTABLISHED,RELATED rule in INPUT chain?**
   - A) Nothing, rules work fine
   - B) New connections work but return traffic is blocked
   - C) Only outgoing traffic is affected
   - D) All traffic is blocked

2. **In which chain should you add rules to filter traffic to published Docker ports in Colima?**
   - A) FORWARD
   - B) DOCKER
   - C) DOCKER-USER
   - D) INPUT

3. **What's the correct order for iptables INPUT rules?**
   - A) DROP rules first, then ACCEPT rules
   - B) ACCEPT rules first, then DROP rules
   - C) Most specific rules first, then general rules
   - D) Order doesn't matter

## 🧹 Cleanup

When you're done with the lab:

```bash
# Stop and remove containers
docker stop public-web admin-panel database business-app 2>/dev/null || true
docker rm public-web admin-panel database business-app 2>/dev/null || true

# Remove our test rules (adjust ports as needed)
sudo iptables -D INPUT -p tcp --dport 8080 -j DROP 2>/dev/null || true
sudo iptables -D INPUT -p tcp --dport 8081 -j DROP 2>/dev/null || true
sudo iptables -D INPUT -p tcp --dport 3306 -j DROP 2>/dev/null || true
sudo iptables -D INPUT -p tcp --dport 8082 -j DROP 2>/dev/null || true

# List INPUT rules to verify cleanup
sudo iptables -L INPUT -n --line-numbers
```

## 🎉 Solutions

<details>
<summary>Click to see Exercise 2 complete solution</summary>

```bash
# Allow established connections first
sudo iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow public web server (port 8080) from anywhere
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT

# Allow admin panel (port 8081) from local network only
sudo iptables -I INPUT -p tcp --dport 8081 -s 192.168.1.0/24 -j ACCEPT

# Allow database (port 3306) from localhost only  
sudo iptables -I INPUT -p tcp --dport 3306 -s 127.0.0.1 -j ACCEPT

# Drop traffic to restricted ports from other sources
sudo iptables -A INPUT -p tcp --dport 8081 -j DROP
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP
```

</details>

<details>
<summary>Click to see Self-Assessment Answers</summary>

1. **B** - New connections work but return traffic is blocked
2. **D** - INPUT (in Colima environment)
3. **C** - Most specific rules first, then general rules

</details>

## 📝 Lab Report

Document your experience:
1. Which exercises were challenging?
2. What errors did you encounter?
3. How did the INPUT chain approach differ from what you expected?
4. What would you do differently in production?

---
**🎓 Congratulations!** You've completed the Docker INPUT chain firewall restrictions lab.
