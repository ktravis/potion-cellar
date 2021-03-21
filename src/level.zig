const std = @import("std");

// usingnamespace @import("math.zig");
const zlm = @import("zlm");
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;

pub const TileType = enum {
    EMPTY,
    WALL,

    pub fn solid(t: TileType) bool {
        return switch (t) {
            .WALL => true,
            else => false,
        };
    }
};

pub fn coordsEqual(a: Level.Coord, b: Level.Coord) bool {
    return a.x == b.x and a.y == b.y;
}

pub const Level = struct {
    pub const TILE_SCALE: f32 = 2.0;
    pub const MAX_WIDTH = 64;
    pub const MAX_HEIGHT = 64;

    width: usize = 0,
    height: usize = 0,

    grid: [MAX_HEIGHT][MAX_WIDTH]TileType = undefined,

    pub fn init(level: []const u8) Level {
        var result: Level = .{};
        var x: usize = 0;
        var y: usize = 0;
        for (level) |c| {
            switch (c) {
                'o' => result.grid[y][x] = .WALL,
                '.' => result.grid[y][x] = .EMPTY,
                '\n' => {
                    y += 1;
                    x = 0;
                    continue;
                },
                else => {},
            }
            x += 1;
        }
        result.width = x;
        result.height = y + 1;
        return result;
    }

    pub const Coord = @import("zlm").specializeOn(i64).Vec2;

    // pub const Coord = struct {
    //     x: i64 = 0,
    //     y: i64 = 0,

    //     pub fn equals(self: Coord, other: Coord) bool {
    //         return self.x == other.x and self.y == other.y;
    //     }
    // };

    pub fn toGridCoord(self: Level, pos: Vec3) Coord {
        return .{
            .x = @floatToInt(i64, pos.x / TILE_SCALE),
            .y = @floatToInt(i64, pos.z / TILE_SCALE),
        };
    }

    pub fn fromGridCoord(self: Level, c: Coord) Vec3 {
        return .{
            .x = @intToFloat(f32, c.x) * TILE_SCALE,
            .y = 0,
            .z = @intToFloat(f32, c.y) * TILE_SCALE,
        };
    }

    pub fn at(self: Level, c: Coord) TileType {
        return self.grid[@intCast(usize, c.y)][@intCast(usize, c.x)];
    }

    pub fn contains(self: Level, c: Coord) bool {
        return c.x > 0 and c.y > 0 and c.x < self.width and c.y < self.height;
    }

    pub fn collide(self: Level, c: Coord) bool {
        if (!self.contains(c)) return true;
        return self.at(c).solid();
    }

    pub const Iterator = struct {
        level: *Level,
        _next: ?Coord = Coord.zero,

        pub fn next(self: *Iterator) ?Coord {
            const n = self._next;
            if (n) |m| {
                var _next = m;
                _next.x += 1;
                if (_next.x >= self.level.width) {
                    _next.x = 0;
                    _next.y += 1;
                    if (_next.y >= self.level.height) {
                        self._next = null;
                        return n;
                    }
                }
                self._next = _next;
            }
            return n;
        }
    };

    pub fn iter(self: *Level) Iterator {
        return .{ .level = self };
    }
};
