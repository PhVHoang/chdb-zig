const std = @import("std");

const c = @cImport({
    @cInclude("chdb.h");
});

pub const ChdbError = error{
    QueryFailed,
    NullResult,
};

pub const QueryResult = struct {
    buf: ?[*]u8,
    len: usize,
    elapsed: f64,
    rows_read: u64,
    bytes_read: u64,
    error_message: ?[*:0]u8,
    _internal: ?*c.struct_local_result_v2,

    /// Free the underlying C result
    pub fn deinit(self: QueryResult) void {
        c.free_result_v2(self._internal);
    }

    /// Get the result as a string slice
    pub fn data(self: QueryResult) []const u8 {
        return self.buf;
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

    const c_result = c.query_stable_v2(2, argv) orelse return ChdbError.NullResult;
    errdefer c.free_result_v2(c_result);

    // Handle error separately
    if (c_result.error_message) |err_ptr| {
        const err_msg = std.mem.span(@as([*:0]const u8, @ptrCast(err_ptr)));
        std.log.err("ChDB query failed: {s}", .{err_msg});
        return ChdbError.QueryFailed;
    }

    // Validate result buffer
    const buf_ptr = c_result.buf orelse return ChdbError.QueryFailed;
    const buf_slice = buf_ptr[0..c_result.len];

    return QueryResult{
        .buf = buf_slice,
        .elapsed = c_result.elapsed,
        .rows_read = c_result.rows_read,
        .bytes_read = c_result.bytes_read,
        ._internal = c_result,
    };
}

test "simple query" {
    const result = try query("SELECT 1", std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(result.buf.len > 0);
    try std.testing.expect(result.rows_read > 0);
}

test "query with error handling" {
    // This should fail with invalid SQL
    const result = query("INVALID SQL SYNTAX", std.testing.allocator);
    try std.testing.expectError(ChdbError.QueryFailed, result);
}
