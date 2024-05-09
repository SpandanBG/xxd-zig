const std = @import("std");

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const max_char_per_col: u8 = 8;
const max_hex_line_size: u8 = max_char_per_col * 6 + 7;

const Config = struct {
    input_file: [:0]const u8,
    output_file: ?[:0]const u8 = null,
};

const ArgsError = error{INVALID_CLI_ARGS};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const config = try get_cli_args(allocator);

    const out_file = get_output_writer(config.output_file) catch |err| {
        std.log.err("error occured while preparing output stream = {any}", .{err});
        return;
    };
    defer out_file.close();

    hex_dump(config.input_file, out_file, allocator);
}

fn get_cli_args(allocator: Allocator) ArgsError!Config {
    var argsIter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer argsIter.deinit();

    _ = argsIter.next(); // Skip first arg (process bin path)

    var input_file: [:0]const u8 = undefined;
    if (argsIter.next()) |i_file_name| {
        input_file = i_file_name;
    } else {
        std.log.err("expected input file path as first cmd line arg", .{});
        return ArgsError.INVALID_CLI_ARGS;
    }

    var config: Config = .{ .input_file = input_file };

    if (argsIter.next()) |o_file_name| {
        config.output_file = o_file_name;
    }

    return config;
}

fn hex_dump(input_file: [:0]const u8, out: File, allocator: Allocator) void {
    const i_file = std.fs.cwd().openFile(input_file, .{}) catch |err| {
        std.log.err("error occured while opening the file = {any}", .{err});
        return;
    };
    defer i_file.close();

    var line_hex_str: [15:0]u8 = undefined; // 8 len hex + ": " + 5 extra for the `{  }%`.
    var line_no: u64 = 0;

    // Prepare the line to be written to the output file
    var write_str = std.ArrayList(u8).init(allocator);
    defer write_str.deinit();

    // Prepare the actual string to be appended to the output file
    var actual_str = std.ArrayList(u8).init(allocator);
    defer actual_str.deinit();

    var buf: [2:0]u8 = undefined;
    var should_read_next: bool = true;

    var col_no: u8 = 0;
    while (should_read_next) outer_loop: {
        write_str.clearRetainingCapacity();
        actual_str.clearRetainingCapacity();
        col_no = 0;

        (blk: {
            _ = std.fmt.bufPrint(&line_hex_str, "{x:0>8}: ", .{line_no}) catch |err| break :blk err;
            write_str.appendSlice(line_hex_str[0..]) catch |err| break :blk err;
            line_no += 0x10;
        }) catch |err| {
            std.log.err("error occured while saving to output string = {any}", .{err});
            return;
        };

        while (col_no < max_char_per_col) : (col_no += 1) {
            const r_size = i_file.read(&buf) catch |err| {
                std.log.err("error occured while reading from input file = {any}", .{err});
                return;
            };
            should_read_next = r_size == buf.len;
            if (r_size == 0) break;

            const hex_str = dec_to_hex(buf.len, &buf) catch |err| {
                std.log.err("error occured while creating a hex buffer string = {any}", .{err});
                return;
            };

            (blk: {
                write_str.appendSlice(hex_str[0 .. r_size * 2]) catch |err| break :blk err;
                write_str.append(' ') catch |err| break :blk err;
            }) catch |err| {
                std.log.err("error occured while saving to output string = {any}", .{err});
                return;
            };

            std.mem.replaceScalar(u8, buf[0..], '\n', '.');
            std.mem.replaceScalar(u8, buf[0..], '\r', '.');
            std.mem.replaceScalar(u8, buf[0..], '\x00', '.');
            actual_str.appendSlice(buf[0..r_size]) catch |err| {
                std.log.err("error occured while saving actual string = {any}", .{err});
                return;
            };
        }

        if (actual_str.items.len == 0) break :outer_loop;

        (blk: {
            const no_of_ws = 2 + max_hex_line_size - write_str.items.len;
            for (0..no_of_ws) |_| write_str.append(' ') catch |err| break :blk err;
            write_str.appendSlice(actual_str.items[0..actual_str.items.len]) catch |err| break :blk err;
            write_str.append('\n') catch |err| break :blk err;
        }) catch |err| {
            std.log.err("error occured preparing final write string = {any}", .{err});
            return;
        };

        _ = out.write(write_str.items[0..write_str.items.len]) catch |err| {
            std.log.err("error occured while writing to output file = {any}", .{err});
            return;
        };
    }
}

fn get_output_writer(out_file: ?([:0]const u8)) File.OpenError!File {
    const filename = out_file orelse return std.io.getStdOut();
    return std.fs.cwd().createFile(filename, .{});
}

fn dec_to_hex(comptime n: usize, dec: *const [n:0]u8) std.fmt.BufPrintError![n * 2:0]u8 {
    var hex: [n * 2:0]u8 = undefined;
    var buf: [7:0]u8 = undefined;

    for (dec, 0..) |char, i| {
        const inp: [1:0]u8 = .{char};
        _ = try std.fmt.bufPrint(&buf, "{x:0>2}", .{inp});

        for (buf[2..4], i * 2..) |hex_char, j| hex[j] = hex_char;
    }

    return hex;
}
