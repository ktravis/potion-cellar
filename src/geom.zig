const std = @import("std");
const zlm = @import("zlm");
const vec2 = zlm.vec2;
const Vec2 = zlm.Vec2;
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;

const white = 0xffffffff;

pub const Rect = struct {
    pos: Vec2,
    w: f32,
    h: f32,

    pub fn dim(self: Rect) Vec2 {
        return vec2(self.w, self.h);
    }
};

pub const UVRect = struct {
    a: Vec2 = .{ .x = 0, .y = 0 },
    b: Vec2 = .{ .x = 1, .y = 1 },

    pub fn flipY(self: UVRect) UVRect {
        var out = self;
        const tmp = out.a.y;
        out.a.y = out.b.y;
        out.b.y = tmp;
        return out;
    }
};

// a vertex struct with position, color, uv-coords, and normal
pub const Vertex = packed struct {
    x: f32,
    y: f32,
    z: f32,
    color: u32 = white,
    u: f32 = 0,
    v: f32 = 0,
    nx: f32 = 0,
    ny: f32 = 0,
    nz: f32 = 0,

    pub fn translate(v: Vertex, by: Vec3) Vertex {
        var out = v;
        out.x += by.x;
        out.y += by.y;
        out.z += by.z;
        return out;
    }
};

pub const quad = struct {
    pub const vertices = &generateVertices(vec2(-0.5, -0.5), vec2(1, 1), .{}, white);

    pub const indices = &indicesWithOffset(0);

    pub fn indicesWithOffset(o: u16) [6]u16 {
        return [_]u16{
            o + 0, o + 1, o + 2, o + 0, o + 2, o + 3,
        };
    }

    pub fn generateVertices(pos: Vec2, size: Vec2, uv: UVRect, tint: u32) [4]Vertex {
        return [_]Vertex{
            .{
                .x = pos.x,
                .y = pos.y,
                .z = 0,
                .color = tint,
                .u = uv.a.x,
                .v = uv.b.y,
                .nz = 1.0,
            },
            .{
                .x = pos.x + size.x,
                .y = pos.y,
                .z = 0,
                .color = tint,
                .u = uv.b.x,
                .v = uv.b.y,
                .nz = 1.0,
            },
            .{
                .x = pos.x + size.x,
                .y = pos.y + size.y,
                .z = 0,
                .color = tint,
                .u = uv.b.x,
                .v = uv.a.y,
                .nz = 1.0,
            },
            .{
                .x = pos.x,
                .y = pos.y + size.y,
                .z = 0,
                .color = tint,
                .u = uv.a.x,
                .v = uv.a.y,
                .nz = 1.0,
            },
        };
    }
};

pub const cube = struct {
    pub const north_face_verts = &[_]Vertex{
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = 1, .v = 1, .nz = -1.0 },
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = 1, .v = 0, .nz = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nz = -1.0 },
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = 1, .nz = -1.0 },
    };

    pub const south_face_verts = &[_]Vertex{
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = 0, .nz = 1 },
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = 1, .v = 0, .nz = 1 },
        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = 1, .v = 1, .nz = 1 },
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = 0, .v = 1, .nz = 1 },
    };

    pub const west_face_verts = &[_]Vertex{
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = 1, .v = 1, .nx = -1.0 },
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = 1, .v = 0, .nx = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nx = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = 1, .nx = -1.0 },
    };

    pub const east_face_verts = &[_]Vertex{
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nx = 1 },
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = 1, .v = 0, .nx = 1 },
        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = 1, .v = 1, .nx = 1 },
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = 1, .nx = 1 },
    };

    pub const bottom_face_verts = &[_]Vertex{
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = 1, .v = 1, .ny = -1 },
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = 1, .v = 0, .ny = -1 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .ny = -1 },
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 1, .ny = -1 },
    };

    pub const top_face_verts = &[_]Vertex{
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .ny = 1 },
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = 1, .v = 0, .ny = 1 },
        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = 1, .v = 1, .ny = 1 },
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = 1, .ny = 1 },
    };
    pub const vertices = north_face_verts ++
        south_face_verts ++
        west_face_verts ++
        east_face_verts ++
        bottom_face_verts ++
        top_face_verts;

    // cube index buffer
    pub const indices = comptime blk: {
        var arr: []const u16 = &[_]u16{};
        var i = 0;
        while (i < 6) : (i += 1) {
            arr = arr ++ quad.indicesWithOffset(4 * i);
        }
        break :blk arr;
    };
};
