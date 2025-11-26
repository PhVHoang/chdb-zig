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
    var argv_buf = try allocator.alloc([*c]u8, 2);
    defer allocator.free(argv_buf);

    // Program name (null-terminated)
    const prog = try allocator.dupeZ(u8, "zigg");
    defer allocator.free(prog);

    // SQL query (null-terminated)
    const sql_z = try allocator.dupeZ(u8, sql);
    defer allocator.free(sql_z);

    argv_buf[0] = @as([*c]u8, @ptrCast(prog.ptr));
    argv_buf[1] = @as([*c]u8, @ptrCast(sql_z.ptr));

    // Cast to C-compatible argv type
    const argv = @as([*c][*c]u8, @ptrCast(argv_buf.ptr));

    const c_result = c.query_stable_v2(2, argv);
    if (c_result == null) {
        return ChdbError.QueryFailed;
    }

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
