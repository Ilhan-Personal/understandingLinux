# GDB Debugging Instructions

## Compilation
1. Compile the program with debugging symbols:

```bash
gcc -g test.c -o test
```

## Starting GDB
2. Launch GDB with the program:

```bash
gdb test
```

## Basic GDB Commands
3. Common debugging commands:

- Set a breakpoint at line 10:
```bash
break 10
```
- Run the program:
```bash
run
```
- Show all breakpoints:
```bash
info breakpoints
```
- View register values:
```bash
info registers
```

4. To quit GDB:
```bash
quit
```

# GitHub PAT Verification

To check if a GitHub Personal Access Token (PAT) is still active:

1. Using curl:
```bash
curl -H "Authorization: token YOUR_PAT_HERE" https://api.github.com/user
```

2. Using the GitHub API directly in browser:
   - Go to: https://api.github.com/user
   - Add your token as Authorization header

3. Expected responses:
   - Valid token: Returns your GitHub user information in JSON format
   - Invalid token: Returns a 401 Unauthorized error

Note: Replace `YOUR_PAT_HERE` with your actual Personal Access Token.

## Security Tips
- Never share your PAT
- Use tokens with minimal required permissions
- Regularly rotate your tokens
- Remove unused tokens from GitHub Settings > Developer Settings > Personal Access Tokens
