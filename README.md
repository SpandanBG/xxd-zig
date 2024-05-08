# XXD - Zig

Toy implemenations of the `xxd` linux command in Zig

# Run

```shell
zig build run -- ./mocks/hello.txt ./mocks/hello.hex && cat ./mocks/hello.hex
```

Example output:
```
info: running xxd from ./mocks/hello.txt to ./mocks/hello.hex
info: done writing
0000000000: 68 65 6C 6C 6F 2C 20 77 6F 72 6C 64 21     hello, world!
```
