const std = @import("std");

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const max_char_per_col: u8 = 16;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var argsIter = try std.process.ArgIterator.initWithAllocator(allocator);
    _ = argsIter.next(); // Skip first arg (process bin path)

    var input_file: [:0]const u8 = undefined;
    if (argsIter.next()) |arg| {
        input_file = arg;
    } else {
        std.log.err("expected input file path as first cmd line arg", .{});
        return;
    }

    const out_file = get_output_writer(argsIter.next()) catch |err| {
        std.log.err("error occured while preparing output stream = {any}", .{err});
        return;
    };
    defer out_file.close();

    dump_file(input_file, out_file, allocator);
}

fn dump_file(input_file: [:0]const u8, out: File, allocator: Allocator) void {
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

    var buf: [1:0]u8 = undefined;
    var should_read_next: bool = true;

    var col_no: u8 = 1;
    while (should_read_next) outer_loop: {
        write_str.clearRetainingCapacity();
        actual_str.clearRetainingCapacity();
        col_no = 1;

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
            if (should_read_next == false) break;

            const hex_str = dec_to_hex(buf.len, &buf) catch |err| {
                std.log.err("error occured while creating a hex buffer string = {any}", .{err});
                return;
            };

            (blk: {
                write_str.appendSlice(&hex_str) catch |err| break :blk err;
                write_str.append(' ') catch |err| break :blk err;
            }) catch |err| {
                std.log.err("error occured while saving to output string = {any}", .{err});
                return;
            };

            std.mem.replaceScalar(u8, buf[0..], '\n', '.');
            std.mem.replaceScalar(u8, buf[0..], '\r', '.');
            std.mem.replaceScalar(u8, buf[0..], '\x00', '.');
            actual_str.appendSlice(&buf) catch |err| {
                std.log.err("error occured while saving actual string = {any}", .{err});
                return;
            };
        }

        if (actual_str.items.len == 0) break :outer_loop;

        (blk: {
            write_str.appendSlice(" " ** 4) catch |err| break :blk err;
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
