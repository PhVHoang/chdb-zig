# zigg - Zig Bindings for chDB

A Zig language binding for [chDB](https://github.com/chdb-io/chdb), an embedded SQL query engine that brings ClickHouse to your application.

## Overview

`zigg` provides a simple and idiomatic Zig interface to chDB's C API. It enables you to execute SQL queries directly from Zig code without managing external database servers.

## Features

- **Simple Query API**: Execute SQL queries with a single function call
- **Memory Safe**: Proper resource cleanup via `deinit()` methods
- **Type-Safe**: Leverages Zig's type system for safer bindings
- **Error Handling**: Comprehensive error types for query failures

## Installation

### Prerequisites

- Zig 0.13.0 or later
- libchdb (pre-built or compiled)

### Build

```bash
zig build
```

### Run

```bash
zig build run
```

### Test

```bash
zig build test
```

## Quick Start

```zig
const std = @import("std");
const chdb = @import("chdb.zig");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    // Execute a simple query
    var result = try chdb.query("SELECT 1 as x", allocator);
    defer result.deinit();

    // Access result data
    std.debug.print("Result: {s}\n", .{result.buf[0..result.len]});
    std.debug.print("Rows read: {d}\n", .{result.rows_read});
    std.debug.print("Elapsed: {d}ms\n", .{result.elapsed * 1000});
}
```

## API Reference

### `query(sql: []const u8, allocator: std.mem.Allocator) !QueryResult`

Executes a SQL query and returns the result.

**Parameters:**
- `sql`: SQL query string
- `allocator`: Memory allocator for temporary string allocations

**Returns:**
- `QueryResult` on success
- `ChdbError.QueryFailed` if the query fails

**Example:**
```zig
var result = try chdb.query("SELECT * FROM system.tables LIMIT 1", allocator);
defer result.deinit();
```

### `QueryResult` Structure

```zig
pub const QueryResult = struct {
    buf: [*]u8,              // Result buffer pointer
    len: usize,              // Result buffer length
    elapsed: f64,            // Query execution time (seconds)
    rows_read: u64,          // Number of rows read
    bytes_read: u64,         // Number of bytes read
    error_message: ?[*:0]u8, // Error message (if any)
    _internal: ?*c.struct_local_result_v2,

    pub fn deinit(self: *QueryResult) void
};
```

**Fields:**
- `buf`: Pointer to the result data buffer
- `len`: Length of the result data in bytes
- `elapsed`: Query execution time in seconds
- `rows_read`: Total rows read during query execution
- `bytes_read`: Total bytes read during query execution
- `error_message`: Error message if query failed (null if successful)

## Project Structure

```
.
├── build.zig                 # Build configuration
├── build.zig.zon            # Build dependencies
├── libchdb/
│   ├── chdb.h               # chDB C header
│   └── libchdb.so           # Pre-built chDB library (not included in the repo, should be downloaded locally)
├── src/
│   ├── chdb.zig             # Main binding module
│   ├── main.zig             # Example application
│   └── root.zig             # Library root
├── test/
│   └── test_basic.zig       # Basic tests
└── README.md
```

## Architecture

The binding uses chDB's stable query interface (`query_stable_v2`) to execute SQL:

1. Accepts Zig strings and allocator
2. Converts strings to C-compatible null-terminated format
3. Calls the C API
4. Returns results wrapped in a memory-safe `QueryResult` struct
5. Cleanup via `deinit()` calls the underlying C free functions

## Error Handling

All errors are represented by the `ChdbError` enum:

```zig
pub const ChdbError = error{
    QueryFailed,  // Query execution failed
    OutOfMemory,  // Memory allocation failed
};
```

**Example:**
```zig
var result = chdb.query("SELECT * FROM nonexistent", allocator) catch |err| {
    std.debug.print("Query failed: {}\n", .{err});
    return;
};
defer result.deinit();

if (result.error_message) |err| {
    std.debug.print("Query error: {s}\n", .{err});
}
```

## Examples

### Basic Query

```zig
var result = try chdb.query("SELECT 42 as answer", allocator);
defer result.deinit();
std.debug.print("{s}\n", .{result.buf[0..result.len]});
```

### Query with Elapsed Time

```zig
var result = try chdb.query("SELECT COUNT(*) FROM system.tables", allocator);
defer result.deinit();
std.debug.print("Query took {d}ms\n", .{result.elapsed * 1000});
```

### Handling Errors

```zig
var result = chdb.query("INVALID SQL", allocator) catch |err| {
    std.debug.print("Error: {}\n", .{err});
    return err;
};
defer result.deinit();
```

## Development

### Building for Debug

```bash
zig build -Doptimize=Debug
```

### Building for Release

```bash
zig build -Doptimize=ReleaseFast
```

### Running Tests

```bash
zig build test
```

## Troubleshooting

### Linker Error: Cannot Find libchdb

Ensure `libchdb.so` is in the `libchdb/` directory or adjust the path in `build.zig`:

```zig
exe.addObjectFile(b.path("path/to/libchdb.so"));
```

### Runtime Error: Query Failed

Check the query syntax and ensure chDB supports the SQL dialect. See [chDB documentation](https://github.com/chdb-io/chdb).

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## References

- [chDB GitHub Repository](https://github.com/chdb-io/chdb)
- [C Interoperability in Zig](https://ziglang.org/documentation/master/#C)