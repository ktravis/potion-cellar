const std = @import("std");

pub fn Buffer(comptime T: type, count: comptime_int) type {
    return struct {
        const Self = @This();
        data: [count]T = undefined,
        items: []T = &[_]T{},

        pub fn reset(self: *Self) void {
            self.items.len = 0;
        }

        pub fn add(self: *Self, item: T) usize {
            std.debug.assert(self.items.len < count);
            self.data[self.items.len] = item;
            self.items = self.data[0 .. self.items.len + 1];
            return self.items.len;
        }

        pub fn addSlice(self: *Self, items: []const T) usize {
            for (items) |it| _ = self.add(it);
            return self.items.len;
        }
    };
}
