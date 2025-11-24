const std = @import("std");
const chdb = @import("../src/chdb.zig");

test "open and simple query" {
    const allocator = std.heap.c_allocator;
    var conn = try chdb.Connection.open(":memory:", allocator);
    defer conn.deinit();

    const res = try conn.query("SELECT 1", null);
    defer allocator.free(res);

    try std.testing.expect(res.len > 0);
}
