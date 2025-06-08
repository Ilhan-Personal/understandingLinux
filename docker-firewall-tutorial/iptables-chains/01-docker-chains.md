# Docker's Custom IPTables Chains

## Overview

Docker creates several custom chains in the `filter` table to manage container networking. Understanding these chains is crucial for implementing custom security rules.

## Docker's Custom Chains

### 1. **DOCKER-USER** 🔧
- **Purpose**: User-defined rules that are processed FIRST
- **When to use**: Add your custom security rules here
- **Priority**: Highest - processed before all other Docker chains

```bash
# Example: Block all traffic except from specific IP
iptables -I DOCKER-USER -i eth0 ! -s 192.168.1.100 -j DROP
```

### 2. **DOCKER-FORWARD** 🚀
- **Purpose**: First stage of Docker's packet processing
- **Function**: 
  - Passes packets for established connections
  - Routes new packets to other Docker chains
- **Note**: Don't modify this chain directly

### 3. **DOCKER** 🐳
- **Purpose**: Controls access to published container ports
- **Function**: Determines if new connections should be accepted
- **Auto-managed**: Docker creates rules here based on `-p` flags

### 4. **DOCKER-ISOLATION-STAGE-1 & STAGE-2** 🔒
- **Purpose**: Network isolation between different Docker networks
- **Function**: Prevents containers in different networks from communicating
- **Auto-managed**: Based on your network configuration

### 5. **DOCKER-INGRESS** 🌐
- **Purpose**: Swarm mode networking rules
- **Function**: Handles Docker Swarm service discovery and load balancing
- **Scope**: Only relevant for Docker Swarm deployments

## Chain Processing Order

```
FORWARD Chain
    ↓
DOCKER-USER (Your custom rules)
    ↓
DOCKER-FORWARD (Docker's main processing)
    ↓
DOCKER (Port access control)
    ↓
DOCKER-ISOLATION-* (Network isolation)
    ↓
DOCKER-INGRESS (Swarm networking)
```

## Key Rules Docker Adds

### In FORWARD Chain:
```bash
# Jump to Docker's custom chains
-A FORWARD -j DOCKER-USER
-A FORWARD -j DOCKER-FORWARD  
-A FORWARD -j DOCKER-INGRESS
```

### Default Policy:
```bash
# Docker sets FORWARD chain policy to DROP
-P FORWARD DROP
```

## Why DOCKER-USER is Special

- **Processed first**: Your rules run before Docker's rules
- **Can override**: Your rules can accept/reject packets before Docker sees them
- **Persistent**: Rules survive container restarts
- **Safe**: Docker doesn't modify this chain

## Viewing Docker's Chains

```bash
# List all chains in filter table
iptables -L -n -v

# View specific Docker chain
iptables -L DOCKER-USER -n -v

# View with line numbers
iptables -L DOCKER-USER -n --line-numbers
```

## Common Mistakes ❌

1. **Adding rules to FORWARD chain**: These run AFTER Docker's rules
2. **Modifying DOCKER chain**: Docker will overwrite your changes
3. **Ignoring DOCKER-USER**: This is where your custom rules belong

## Best Practices ✅

1. **Always use DOCKER-USER** for custom rules
2. **Insert rules at the top** with `-I` flag
3. **Test rules carefully** before applying in production
4. **Document your rules** for future reference

---
**💡 Remember**: DOCKER-USER is your friend - it's the only chain Docker won't touch! 
