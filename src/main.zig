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

    // Query with Elapsed Time
    var result_1 = try chdb.query("SELECT COUNT(*) FROM system.tables", allocator);
    defer result_1.deinit();
    std.debug.print("Query took {d}ms\n", .{result_1.elapsed * 1000});

    if (result_1.len > 0) {
        std.debug.print("{s}\n", .{result_1.buf[0..result_1.len]});
    }
    if (result_1.error_message) |err_msg| {
        std.debug.print("Error: {s}\n", .{err_msg});
    }

    // Handling Error
    var result_2 = chdb.query("INVALID SQL", allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer result_2.deinit();
}
