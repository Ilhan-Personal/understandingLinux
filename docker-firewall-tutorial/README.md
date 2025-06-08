# Docker Packet Filtering and Firewalls Tutorial

## 💻 macOS Users with Colima

**Good news!** If you're using Colima on macOS, you can follow this tutorial:

```bash
# Start Colima if not running
colima start

# SSH into your Colima Linux VM  
colima ssh

# Now you're in a Linux environment where all tutorial commands work!
```

All `iptables` and `docker` commands in this tutorial will work inside the Colima VM.

## ⚠️ macOS Compatibility Notice

**This tutorial is designed for Linux systems.** If you're on macOS:
- iptables commands won't work directly (macOS uses pfctl)
- Docker Desktop runs in a Linux VM with limited firewall access
- Consider using a Linux VM (VirtualBox, Parallels, or UTM) for hands-on practice
- Alternatively, use cloud instances (AWS EC2, DigitalOcean, etc.)

## 🎯 Learning Objectives

By the end of this tutorial, you will understand:
- How Docker integrates with iptables for network security
- Docker's custom iptables chains and their purposes
- How to add custom firewall rules for Docker containers
- Best practices for securing Docker deployments
- Troubleshooting common networking issues

## 📚 Tutorial Structure

### 1. **Basics** (`basics/`)
- Introduction to Docker networking and iptables
- Understanding packet flow in Docker
- Key concepts and terminology

### 2. **IPTables Chains** (`iptables-chains/`)
- Deep dive into Docker's custom chains
- Chain hierarchy and packet processing order
- Rule precedence and execution flow

### 3. **Practical Examples** (`practical-examples/`)
- Real-world scenarios and solutions
- Step-by-step implementations
- Common security patterns

### 4. **Exercises** (`exercises/`)
- Hands-on labs and challenges
- Self-assessment questions
- Practice scenarios

### 5. **Scripts** (`scripts/`)
- Utility scripts for testing and demonstration
- Automation helpers
- Diagnostic tools

## 🚀 Quick Start

1. Start with `basics/01-introduction.md`
2. Follow the numbered sequence in each directory
3. Complete exercises before moving to the next section
4. Use the scripts directory for hands-on practice

## ⚠️ Prerequisites

- Basic understanding of Linux networking
- Docker installed and running
- Root/sudo access for iptables commands
- Basic command line knowledge

## 🛡️ Safety Notice

**Always test firewall rules in a safe environment first!**
- Use virtual machines or containers for testing
- Keep backup access methods available
- Test rules before applying in production

---

**Happy Learning!** 🐳🔥 
