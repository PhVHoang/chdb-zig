┌─────────────────────────────────────────────────────────────────┐
│ ZIG CODE (your application)                                     │
│                                                                 │
│ var db = try Connection.init(allocator, ":memory:");            │
│ var result = try db.query("SELECT 1", "CSV");                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ Calls extern "c" functions
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ C API LAYER (chdb.h - the bridge)                               │
│                                                                 │
│ chdb_connection* chdb_connect(int argc, char\*\* argv);         │
│ chdb_result* chdb_query(chdb_connection, const char\*, ...);    │
│                                                                 │
│ • Simple C types only                                           │
│ • No C++ features                                               │
│ • Stable ABI                                                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ Calls C++ code internally
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ C++ IMPLEMENTATION (chdb's internal code)                       │
│                                                                 │
│ class ClickHouseDatabase {                                      │
│ std::vector<char> executeQuery(...);                            │
│ };                                                              │
│                                                                 │
│ • Full C++ features                                             │
│ • Templates, classes, STL                                       │
│ • Complex internal logic                                        │
└─────────────────────────────────────────────────────────────────┘
