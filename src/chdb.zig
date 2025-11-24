const std = @import("std");

const c = @cImport({
    @cInclude("chdb.h");
});

// Small convenience types for C interop
const c_void = @cImport({
    @cInclude("stddef.h");
});

pub const ChdbError = error{
    NullHandle,
    OpenFailed,
    QueryFailed,
    InvalidArgument,
    StreamError,
};

pub const Allocator = std.mem.Allocator;

// A thin, safe wrapper around the chdb_connection opaque handle
pub const Connection = struct {
    conn: ?c.chdb_connection,
    allocator: *Allocator,

    pub fn open(path: []const u8, allocator: *Allocator) !Connection {
        if (path.len == 0) return ChdbError.InvalidArgument;

        // Build argv: program name + --path=<path>
        var gpa = std.heap.GeneralPurposeAllocator(.{}) catch return ChdbError.OpenFailed;

        defer gpa.deinit(); // FIXME
        const arena = &gpa.allocator;
    }

    pub fn close(self: *Connection) void {
        if (self.conn) |h| {
            // header: chdb_close_conn(chdb_connection * conn)
            // We must pass the address of the handle; we stored only the handle, so create a temporary.
            var tmp = h;
            c.chdb_close_conn(@ptrCast(*c.chdb_connection, &tmp));
            self.conn = null;
        }
    }

    pub fn deinit(self: *Connection) void {
        self.close();
    }

    /// Execute a simple query; returns owned byte slice using the connection's allocator.
    pub fn query(self: *Connection, sql: []const u8, format: ?[]const u8) ![]u8 {
        if (self.conn == null) return ChdbError.NullHandle;
        if (sql.len == 0) return ChdbError.InvalidArgument;


        // Build null-terminated C strings on C allocator
        const c_alloc = std.heap.c_allocator;
        const sql_buf = try c_alloc.alloc(u8, sql.len + 1);
        std.mem.copy(u8, sql_buf[0..sql.len], sql);
        sql_buf[sql.len] = 0;


        var format_buf: [?]u8 = null;
        if (format) |f| {
            const fb = try c_alloc.alloc(u8, f.len + 1);
            std.mem.copy(u8, fb[0..f.len], f);
            fb[f.len] = 0;
            format_buf = fb;
        }


        var res = c.chdb_query(self.conn.?, @ptrCast([*]const u8, sql_buf), if (format_buf) |fb| @ptrCast([*]const u8, fb) else null);

        // free temporaries
        c_alloc.free(sql_buf);
        if (format_buf) |fb| c_alloc.free(fb);

        if (res == null) return ChdbError.QueryFailed;

        const buf = c.chdb_result_buffer(res);
        const len = c.chdb_result_length(res);

        // Copy into caller allocator
        const out = try self.allocator.alloc(u8, len);
        std.mem.copy(u8, out, @ptrCast([*]const u8, buf)[0..len]);

        // Optional: expose metadata (elapsed, rows, bytes) via helper functions
        // destroy C result
        c.chdb_destroy_query_result(res);

        return out[0..len];
    }

    /// Streaming API: start -> fetch -> cancel -> destroy
    pub fn stream_query(self: *Connection, sql: []const u8, format: ?[]const u8) !StreamingHandle {
        if (self.conn == null) return ChdbError.NullHandle;
        const c_alloc = std.heap.c_allocator;
        const sql_buf = try c_alloc.alloc(u8, sql.len + 1);
        std.mem.copy(u8, sql_buf[0..sql.len], sql);
        sql_buf[sql.len] = 0;


        var format_buf: [?]u8 = null;
        if (format) |f| {
            const fb = try c_alloc.alloc(u8, f.len + 1);
            std.mem.copy(u8, fb[0..f.len], f);
            fb[f.len] = 0;
            format_buf = fb;
        }

        var stream_res = c.chdb_stream_query(self.conn.?, @ptrCast([*]const u8, sql_buf), if (format_buf) |fb| @ptrCast([*]const u8, fb) else null);

        c_alloc.free(sql_buf);
        if (format_buf) |fb| c_alloc.free(fb);


        if (stream_res == null) return ChdbError.StreamError;
        return StreamingHandle{ .conn = self.conn.?, .result = stream_res, .allocator = self.allocator };
    }
};

/// Handle for streaming queries
pub const StreamingHandle = struct {
    conn: c.chdb_connection,
    result: *c.chdb_result,
    allocator: *Allocator,

    pub fn fetch(self: *StreamingHandle) !?[]u8 {
        if (self.result == null) return ChdbError.StreamError;
        var next = c.chdb_stream_fetch_result(self.conn, self.result);
        if (next == null) return null; // stream ended or error


        const buf = c.chdb_result_buffer(next);
        const len = c.chdb_result_length(next);
        const out = try self.allocator.alloc(u8, len);
        std.mem.copy(u8, out, @ptrCast([*]const u8, buf)[0..len]);
        c.chdb_destroy_query_result(next);
        return out[0..len];
    }

    pub fn cancel(self: *StreamingHandle) void {
        if (self.result != null) {
            c.chdb_stream_cancel_query(self.conn, self.result);
            c.chdb_destroy_query_result(self.result);
            self.result = null;
        }
    }

    pub fn deinit(self: *StreamingHandle) void {
        self.cancel();
    }
};
