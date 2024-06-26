const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;

const StringError = error{OutOfBound};

/// String is a struct that represent well, a string.
/// Fields starting with an underscore `_` must be used as readonly.
pub const String = struct {
    const Self = @This();
    _items: []u8,
    _capacity: usize,
    _len: usize,
    _allocator: Allocator,

    var arena = std.heap.ArenaAllocator{ .child_allocator = std.heap.page_allocator, .state = .{} };

    pub fn new(allocator: ?Allocator, size: usize) String {
        var a = allocator orelse arena.allocator();
        const m = a.alloc(u8, size);
        if (m == Allocator.Error.OutOfMemory) {
            panic("Error while allocating memory for new string.\n", .{});
        }

        return String{
            // we should never be able to reach this `unreachable` since the previous
            // panic
            ._items = m catch unreachable,
            ._capacity = size,
            ._len = 0,
            ._allocator = a,
        };
    }

    pub fn deinit(self: String) void {
        self._allocator.free(self._items);
    }

    pub fn empty(allocator: ?Allocator) String {
        return Self.new(allocator, 0);
    }

    pub fn from_raw(allocator: ?Allocator, str: []const u8) String {
        var s = String.new(allocator, str.len * 2);
        for (str, 0..) |*char, i| {
            s._items[i] = char.*;
        }
        s._len = str.len;

        return s;
    }

    pub fn equals_to_raw(self: *const String, s: []const u8) bool {
        if (self._len != s.len) {
            return false;
        }

        var i: usize = 0;
        while (i < self._len) : (i += 1) {
            if (self._items[i] != s[i]) {
                return false;
            }
        }
        return true;
    }

    pub fn equals_to(self: *const String, s: *const String) bool {
        if (self._len != s._len) {
            return false;
        }

        var i: usize = 0;
        while (i < self._len) : (i += 1) {
            if (self._items[i] != s._items[i]) {
                return false;
            }
        }
        return true;
    }

    pub fn append_raw(self: *String, s: []const u8) *String {
        const str = &String.from_raw(self._allocator, s);
        _ = self.append(str);
        self._allocator.free(str._items);
        return self;
    }

    pub fn append(self: *String, s: *const String) *String {
        if (self._capacity - self._len > s._len) {
            var i: usize = 0;
            while (i < s._len) : (i += 1) {
                self._items[i + self._len] = s._items[i];
            }
            self._len += s._len;
            return self;
        }
        const capacity = (self._capacity + s._capacity) * 2;
        var str = String.new(self._allocator, capacity);
        _ = str.append(self).append(s);
        self._allocator.free(self._items);
        self._items = str._items;
        self._len = str._len;
        self._capacity = str._capacity;
        return self;
    }

    pub fn at(self: *const String, pos: usize) StringError!u8 {
        if (pos > self._len) {
            return StringError.OutOfBound;
        }

        return self._items[pos];
    }

    pub fn substring(self: *const String, start: usize, end: ?usize) StringError!String {
        const end_local: usize = end orelse self._len;

        if (start > self._len) {
            return StringError.OutOfBound;
        }

        if (end_local > self._len) {
            return StringError.OutOfBound;
        }

        const s = self._items[start..end_local];
        return String.from_raw(self._allocator, s);
    }

    pub fn to_raw(self: *const String) []const u8 {
        return self._items[0..self._len];
    }
};

test "create functionality" {
    const s: String = String.new(null, 10);
    assert(s._capacity == 10);
    assert(s._len == 0);

    const empty = String.empty(null);
    assert(empty._capacity == 0);
    assert(empty._len == 0);

    const sRaw: String = String.from_raw(null, "Hello");
    assert(sRaw._capacity == 10);
    assert(sRaw._len == 5);

    var henlo = String.from_raw(null, "hello");
    const toAppend = String.from_raw(null, "a longer string");
    _ = henlo.append(&toAppend);
    assert(henlo._len == 5 + toAppend._len);
}

test "getters" {
    const s = String.from_raw(null, "henloooo");
    _ = s.at(10000) catch |err| {
        assert(err == StringError.OutOfBound);
    };
    const e = try s.at(0);
    assert(e == 'h');

    var s1 = try s.substring(1, 3);
    assert(s1.equals_to_raw("en"));
}
