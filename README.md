# XXD - Zig

Toy implemenations of the `xxd` linux command in Zig

# Run

#### input file to output file
```shell
zig build run -- ./mocks/hello.txt ./mocks/hello.hex && cat ./mocks/hello.hex
```

#### input file to console output
```shell
zig build run -- ./mocks/hello.txt
```

#### Example output:
```
00000000: 6865 6c6c 6f2c 2077 6f72 6c64 210a 6865   hello, world!.he
00000010: 6c6c 6f2c 2065 6172 7468 210a 6865 6c6c   llo, earth!.hell
00000020: 6f2c 206d 6f6f 6e21 0a                    o, moon!.
```
