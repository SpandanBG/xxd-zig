const std = @import("std");

const Allocator = std.mem.Allocator;

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

    var output_file: [:0]const u8 = undefined;
    if (argsIter.next()) |arg| {
        output_file = arg;
    } else {
        std.log.err("expected output file pth as second cmd line arg", .{});
        return;
    }

    std.log.info("running xxd from {s} to {s}", .{ input_file, output_file });
    dump_file(input_file, output_file, allocator);
}

fn dump_file(input_file: [:0]const u8, output_file: [:0]const u8, allocator: Allocator) void {
    const i_file = std.fs.cwd().openFile(input_file, .{}) catch |err| {
        std.log.err("error occured while opening the file = {any}", .{err});
        return;
    };
    defer i_file.close();

    const o_file = std.fs.cwd().createFile(output_file, .{}) catch |err| {
        std.log.err("error occured while creating the file = {any}", .{err});
        return;
    };
    defer o_file.close();

    var hex_str: [7:0]u8 = undefined; // `{ 00 }%` => 7 len with % as EOF.
    var line_hex_str: [17:0]u8 = undefined; // 10 len hex + ": " + 5 extra for the `{  }%`.
    var line_no: u64 = 0;

    // Prepare the line to be written to the output file
    var write_str = std.ArrayList(u8).init(allocator);
    defer write_str.deinit();

    // Prepare the actual string to be appended to the output file
    var actual_str = std.ArrayList(u8).init(allocator);
    defer actual_str.deinit();

    var buf: [1:0]u8 = undefined;
    var should_read_next: bool = true;

    while (should_read_next) outer_loop: {
        write_str.clearRetainingCapacity();
        actual_str.clearRetainingCapacity();

        (blk: {
            _ = std.fmt.bufPrint(&line_hex_str, "{X:0>10}: ", .{line_no}) catch |err| break :blk err;
            write_str.appendSlice(line_hex_str[0..]) catch |err| break :blk err;
            line_no += 1;
        }) catch |err| {
            std.log.err("error occured while saving to output string = {any}", .{err});
            return;
        };

        while (should_read_next) {
            const r_size = i_file.read(&buf) catch |err| {
                std.log.err("error occured while reading from input file = {any}", .{err});
                return;
            };
            should_read_next = r_size == buf.len;

            if (std.mem.eql(u8, &buf, "\n")) break;
            if (std.mem.eql(u8, &buf, "\x00") or should_read_next == false) break :outer_loop;

            _ = std.fmt.bufPrint(&hex_str, "{X:0>2}", .{buf}) catch |err| {
                std.log.err("error occured while creating a hex buffer string = {any}", .{err});
                return;
            };

            write_str.appendSlice(hex_str[2..5]) catch |err| {
                std.log.err("error occured while saving to output string = {any}", .{err});
                return;
            };

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

        _ = o_file.write(write_str.items[0..write_str.items.len]) catch |err| {
            std.log.err("error occured while writing to output file = {any}", .{err});
            return;
        };
    }

    std.log.info("done writing", .{});
}
