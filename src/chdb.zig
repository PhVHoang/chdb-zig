const std = @import("std");

const c = @cImport({
    @cInclude("chdb.h");
});

pub const ChdbError = error{
    NullHandle,
    OpenFailed,
    QueryFailed,
    InvalidArgument,
    StreamError,
    OutOfMemory,
};

pub const Allocator = std.mem.Allocator;

pub const Connection = struct {
    allocator: Allocator,
    handle: c.chdb_connection,

    pub fn open(path: []const u8, allocator: Allocator) !Connection {
        // Build argv: program name + --path=<path>
        const a = std.heap.c_allocator;

        // If using the default memory-backed DB, call with no argv to avoid
        // platform-dependent pointer signedness/casting issues.
        const is_memory = std.mem.eql(u8, path, ":memory:");
        var conn_ptr: ?*c.chdb_connection = null;
        if (is_memory) {
            conn_ptr = c.chdb_connect(0, null);
        } else {
            const prog_slice = try std.fmt.allocPrint(a, "zigg", .{});
            const path_slice = try std.fmt.allocPrint(a, "--path={s}", .{path});

            // allocate null-terminated copies for C argv as signed i8
            var prog_z = try a.alloc(i8, prog_slice.len + 1);
            var i: usize = 0;
            while (i < prog_slice.len) : (i += 1) {
                prog_z[i] = @bitCast(prog_slice[i]);
            }
            prog_z[prog_slice.len] = 0;

            var path_z = try a.alloc(i8, path_slice.len + 1);
            i = 0;
            while (i < path_slice.len) : (i += 1) {
                path_z[i] = @bitCast(path_slice[i]);
            }
            path_z[path_slice.len] = 0;

            var argv: [2][*:0]const u8 = undefined;
            argv[0] = @ptrCast(&prog_z);
            argv[1] = @ptrCast(&path_z);
            // argv[0] = @as(*const i8, &prog_z[0]);
            // argv[1] = @as(*const i8, &path_z[0]);

            const argc: std.os.c_int = 2;
            conn_ptr = c.chdb_connect(argc, argv);
        }
        if (conn_ptr == null) return ChdbError.OpenFailed;
        const conn = conn_ptr.*;
        return Connection{ .allocator = allocator, .handle = conn };
    }

    pub fn deinit(self: *Connection) void {
        if (self.handle != null) {
            // chdb_close_conn expects chdb_connection * (pointer to pointer)
            c.chdb_close_conn(&self.handle);
            self.handle = null;
        }
    }

    pub fn query(self: *Connection, sql: []const u8, format: ?[]const u8) ![]u8 {
        if (self.handle == null) return ChdbError.NullHandle;

        const q_ptr = if (sql.len == 0) null else sql.ptr;
        const f_ptr = if (format) |f| if (f.len == 0) null else f.ptr else null;
        const q_len: usize = sql.len;
        const f_len: usize = if (format) |f| f.len else 0;

        const cres = if (q_len != 0 or f_len != 0) c.chdb_query_n(self.handle, q_ptr, q_len, f_ptr, f_len) else c.chdb_query(self.handle, q_ptr, f_ptr);
        if (cres == null) return ChdbError.QueryFailed;

        const buf = c.chdb_result_buffer(cres);
        const len = usize(c.chdb_result_length(cres));

        if (buf == null or len == 0) {
            // collect error if available
            const err_c = c.chdb_result_error(cres);
            c.chdb_destroy_query_result(cres);
            if (err_c != null) {
                return ChdbError.QueryFailed;
            }
            return try self.allocator.alloc(u8, 0);
        }

        var out = try self.allocator.alloc(u8, len);
        // copy byte-by-byte from C buffer to Zig-allocated buffer
        var i: usize = 0;
        while (i < len) : (i += 1) {
            out[i] = @as(u8, buf[i]);
        }

        c.chdb_destroy_query_result(cres);
        return out;
    }

    pub fn stream_query(self: *Connection, sql: []const u8, format: ?[]const u8) !StreamingResult {
        if (self.handle == null) return ChdbError.NullHandle;

        const q_ptr = if (sql.len == 0) null else sql.ptr;
        const f_ptr = if (format) |f| if (f.len == 0) null else f.ptr else null;
        const q_len: usize = sql.len;
        const f_len: usize = if (format) |f| f.len else 0;

        const cres = if (q_len != 0 or f_len != 0) c.chdb_stream_query_n(self.handle, q_ptr, q_len, f_ptr, f_len) else c.chdb_stream_query(self.handle, q_ptr, f_ptr);
        if (cres == null) return ChdbError.StreamError;

        return StreamingResult{ .allocator = self.allocator, .conn = self, .result = cres };
    }
};

pub const StreamingResult = struct {
    allocator: Allocator,
    conn: *Connection,
    result: *c.chdb_result,

    pub fn fetch(self: *StreamingResult) !?[]u8 {
        if (self.result == null) return null;
        const cres = c.chdb_stream_fetch_result(self.conn.handle, self.result);
        if (cres == null) return null;

        const buf = c.chdb_result_buffer(cres);
        const len = usize(c.chdb_result_length(cres));
        if (buf == null or len == 0) {
            c.chdb_destroy_query_result(cres);
            return null;
        }

        var out = try self.allocator.alloc(u8, len);
        var i: usize = 0;
        while (i < len) : (i += 1) {
            out[i] = @as(u8, buf[i]);
        }

        c.chdb_destroy_query_result(cres);
        return out;
    }

    pub fn deinit(self: *StreamingResult) void {
        if (self.result != null) {
            c.chdb_stream_cancel_query(self.conn.handle, self.result);
            c.chdb_destroy_query_result(self.result);
            self.result = null;
        }
    }
};
