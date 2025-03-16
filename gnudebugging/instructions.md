# GDB Debugging Instructions

## Compilation
1. Compile the program with debugging symbols:

``` gcc -g test.c -o test ```


## Starting GDB
2. Launch GDB with the program:

```gdb test```

## Basic GDB Commands
3. Common debugging commands:

- Set a breakpoint at line 10:
```break `0```
- Run the program:
```run``
- Show all breakpoints:
```info breakpoints```
- View register values:
```info registers```
And keep exploring !

4. To quit GDB:
```quit```
