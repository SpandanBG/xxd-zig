const std = @import("std");

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const Config = struct {
    input_file: ?[:0]const u8 = null,
    output_file: ?[:0]const u8 = null,
    max_char_per_col: usize = 16,
    max_hex_line_size: usize = get_max_hex_line_size(16),
};

const ArgsError = error{INVALID_CLI_ARGS};

const InputFileFlag = "-i";
const OutputFileFlag = "-o";
const ColumnSizeFlag = "-c";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const config = try get_cli_args(allocator);

    const in_file = get_input_reader(config.input_file) catch |err| {
        std.log.err("error occured while preparing input stream = {any}", .{err});
        return;
    };
    defer in_file.close();

    const out_file = get_output_writer(config.output_file) catch |err| {
        std.log.err("error occured while preparing output stream = {any}", .{err});
        return;
    };
    defer out_file.close();

    hex_dump(in_file, out_file, config, allocator);
}

fn get_cli_args(allocator: Allocator) !Config {
    var argsIter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer argsIter.deinit();

    _ = argsIter.next(); // Skip first arg (process bin path)

    var config: Config = .{};

    while (argsIter.next()) |arg| {
        if (std.mem.eql(u8, InputFileFlag, arg)) {
            config.input_file = argsIter.next();
            continue;
        }

        if (std.mem.eql(u8, OutputFileFlag, arg)) {
            config.output_file = argsIter.next();
            continue;
        }

        if (std.mem.eql(u8, ColumnSizeFlag, arg)) {
            config.max_char_per_col = try std.fmt.parseInt(usize, argsIter.next() orelse "", 10);
            config.max_hex_line_size = get_max_hex_line_size(config.max_char_per_col);
            continue;
        }
    }

    return config;
}

fn hex_dump(in: File, out: File, config: Config, allocator: Allocator) void {
    var hex_buf: [10:0]u8 = undefined;
    var should_read_next: bool = true;
    var line_no: u64 = 0;
    var col_no: u8 = 0;

    // Prepare the line to be written to the output file
    var write_str = std.ArrayList(u8).init(allocator);
    defer write_str.deinit();

    // Prepare the actual string to be appended to the output file
    var actual_str = std.ArrayList(u8).init(allocator);
    defer actual_str.deinit();

    while (should_read_next) outer_loop: {
        write_str.clearRetainingCapacity();
        actual_str.clearRetainingCapacity();
        col_no = 0;

        (blk: {
            const line_hex_str = std.fmt.bufPrint(&hex_buf, "{x:0>8}: ", .{line_no}) catch |err| break :blk err;
            write_str.appendSlice(line_hex_str) catch |err| break :blk err;
            line_no += 0x10;
        }) catch |err| {
            std.log.err("error occured while saving to output string = {any}", .{err});
            return;
        };

        for (0..config.max_char_per_col) |i| {
            const maybe_char = file_next_char(in) catch |err| {
                std.log.err("error occured while reading from input file = {any}", .{err});
                return;
            };
            should_read_next = maybe_char != null;
            const char = maybe_char orelse break;

            const hex_str = std.fmt.bufPrint(&hex_buf, "{x:0>2}", .{char}) catch |err| {
                std.log.err("error occured while creating a hex buffer string = {any}", .{err});
                return;
            };

            write_str.appendSlice(hex_str) catch |err| {
                std.log.err("error occured while saving to output string = {any}", .{err});
                return;
            };

            if (i % 2 != 0) {
                write_str.append(' ') catch |err| {
                    std.log.err("error occurd while saving space after hex pair = {any}", .{err});
                    return;
                };
            }

            actual_str.append(if (char == '\n' or char == '\r' or char == '\x00') '.' else char) catch |err| {
                std.log.err("error occured while saving actual string = {any}", .{err});
                return;
            };
        }

        if (actual_str.items.len == 0) break :outer_loop;

        (blk: {
            const no_of_ws = 2 + config.max_hex_line_size - write_str.items.len;
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

fn get_input_reader(input_file: ?([:0]const u8)) File.OpenError!File {
    const filename = input_file orelse return std.io.getStdIn();
    return std.fs.cwd().openFile(filename, .{});
}

fn get_output_writer(out_file: ?([:0]const u8)) File.OpenError!File {
    const filename = out_file orelse return std.io.getStdOut();
    return std.fs.cwd().createFile(filename, .{});
}

fn file_next_char(file: File) !?u8 {
    var buf: [1:0]u8 = undefined;
    const r_size = try file.read(&buf);
    if (r_size == 0) return null;
    return buf[0];
}

fn get_max_hex_line_size(col_size: usize) usize {
    // 8 + 1 (:) + 1 (' ') + 2 * 16(max chars per column) + 16/2 (no. of space after each hex pair) - 1 (remove ending ' ')
    const last_space: usize = if (col_size % 2 == 0) 1 else 0;
    return 10 + 2 * col_size + col_size / 2 - last_space;
}
