const std = @import("std");

const c = @cImport({
    @cInclude("chdb.h");
});

pub const ChdbError = error{
    QueryFailed,
    OutOfMemory,
};

pub const QueryResult = struct {
    buf: [*]u8,
    len: usize,
    elapsed: f64,
    rows_read: u64,
    bytes_read: u64,
    error_message: ?[*:0]u8,
    _internal: ?*c.struct_local_result_v2,

    pub fn deinit(self: *QueryResult) void {
        if (self._internal) |res| {
            c.free_result_v2(res);
            self._internal = null;
        }
    }
};

/// Execute a SQL query using the stable query interface
pub fn query(sql: []const u8, allocator: std.mem.Allocator) !QueryResult {
    // Build argv: ["zigg", "SELECT ..."]
    // Use stack allocation for small fixed-size arrays
    var argv_buf: [2][*c]u8 = undefined;

    // Program name as comptime constant (no allocation needed)
    const prog: [*c]const u8 = "zigg";

    // Only allocate for SQL string (need null terminator)
    const sql_z = try allocator.dupeZ(u8, sql);
    defer allocator.free(sql_z);

    argv_buf[0] = @constCast(prog);
    argv_buf[1] = @ptrCast(sql_z.ptr);

    // Direct cast without intermediate pointer
    const argv: [*c][*c]u8 = &argv_buf;

    const c_result = c.query_stable_v2(2, argv) orelse return ChdbError.QueryFailed;

    return QueryResult{
        .buf = c_result.*.buf,
        .len = c_result.*.len,
        .elapsed = c_result.*.elapsed,
        .rows_read = c_result.*.rows_read,
        .bytes_read = c_result.*.bytes_read,
        .error_message = c_result.*.error_message,
        ._internal = c_result,
    };
}

test "simple query" {
    const allocator = std.heap.c_allocator;
    var result = try query("SELECT 1", allocator);
    defer result.deinit();

    try std.testing.expect(result.len > 0);
}
