# zigg - Zig Bindings for chDB

A Zig language binding for [chDB](https://github.com/chdb-io/chdb), an embedded SQL query engine that brings ClickHouse to your application.

## Overview

`zigg` provides a simple and idiomatic Zig interface to chDB's C API. It enables you to execute SQL queries directly from Zig code without managing external database servers.

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