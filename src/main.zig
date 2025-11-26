const std = @import("std");
const chdb = @import("chdb.zig");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    const sql = "SELECT 1 as x";
    var result = try chdb.query(sql, allocator);
    defer result.deinit();

    std.debug.print("Query returned {d} bytes:\n", .{result.len});
    if (result.len > 0) {
        std.debug.print("{s}\n", .{result.buf[0..result.len]});
    }
    if (result.error_message) |err_msg| {
        std.debug.print("Error: {s}\n", .{err_msg});
    }
}
