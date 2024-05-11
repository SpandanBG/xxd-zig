# XXD - Zig

Toy implemenations of the `xxd` linux command in Zig

## Build
Debug:
```shell
zig build
```

Release Linux:
```shell
zig build -Dtarget=x86_64-linux -Doptimize=ReleaseFast
```

## Build Dirctory
```shell
./zig-out/bin/xxd
```

## Usage 
```shell
Usage:
      xxd [options]
Options:
      -i <file_name>          input file name
      -o <file_name>          output file name
      -c <col_size>           size of the column
      -r                      reverse a hex dump to original
      -p                      pretty print: colored hex. not compatible with -r
      -h                      show this prompt
```

## Run

#### input file to output file
```shell
./zig-out/bin/xxd -i ./mocks/hello.txt -o ./mocks/hello.hex && cat ./mocks/hello.hex
```

#### input file to console output
```shell
./zig-out/bin/xxd -i ./mocks/hello.txt
```

#### input stream to console output
```shell
cat file.txt | ./zig-out/bin/xxd
```

#### Example output:
```
00000000: 6865 6c6c 6f2c 2077 6f72 6c64 210a 6865   hello, world!.he
00000010: 6c6c 6f2c 2065 6172 7468 210a 6865 6c6c   llo, earth!.hell
00000020: 6f2c 206d 6f6f 6e21 0a                    o, moon!.
```

#### Different column size
```shell
$ echo "hello" | zig build run -- -c 8 | xxd -r
hello
```
> Note, here the `xxd` is the actual CLI tool and not the build by this project

#### Reverse hex dump to original
```shell
$ echo "hello" | xxd -c 8 | zig build run -- -r
hello
```
> Note, here the `xxd` is the actual CLI tool and not the build by this project
