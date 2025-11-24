const std = @import("std");
const chdb = @import("chdb.zig");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var conn = try chdb.Connection.open(":memory:", allocator);
    defer conn.deinit();

    const sql = "SELECT 1 as x";
    const res = try conn.query(sql, null);
    defer allocator.free(res);

    std.debug.print("Query returned {d} bytes:\n{s}\n", .{ res.len, res });

    // streaming example (if supported by chdb implementation)
    var stream = try conn.stream_query("SELECT number FROM system.numbers LIMIT 5", null);
    defer stream.deinit();
    while (true) {
        const chunk = try stream.fetch();
        if (chunk == null) break;
        defer allocator.free(chunk.?);
        std.debug.print("stream chunk: {s}\n", .{chunk.?});
    }
}
