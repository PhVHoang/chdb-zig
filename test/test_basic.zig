const std = @import("std");
const chdb = @import("../src/chdb.zig");

test "simple query" {
    const allocator = std.heap.c_allocator;
    var result = try chdb.query("SELECT 1", allocator);
    defer result.deinit();

    try std.testing.expect(result.len > 0);
}
