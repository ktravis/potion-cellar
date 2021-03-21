const zlm = @import("zlm");
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;

const white = 0xffffffff;

pub fn normFloat(f: f32) i16 {
    return @floatToInt(i16, 32767 * f);
}

// a vertex struct with position, color, uv-coords, and normal
pub const Vertex = packed struct {
    x: f32,
    y: f32,
    z: f32,
    color: u32 = white,
    u: i16 = 0,
    v: i16 = 0,
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
    pub const vertices = &[_]Vertex{
        .{
            .x = -0.5,
            .y = -0.5,
            .z = 0,
            .color = 0xffffffff,
            .u = normFloat(0),
            .v = normFloat(0),
            .nz = 1.0,
        },
        .{
            .x = 0.5,
            .y = -0.5,
            .z = 0,
            .color = 0xffffffff,
            .u = normFloat(1),
            .v = normFloat(0),
            .nz = 1.0,
        },
        .{
            .x = 0.5,
            .y = 0.5,
            .z = 0,
            .color = 0xffffffff,
            .u = normFloat(1),
            .v = normFloat(1),
            .nz = 1.0,
        },
        .{
            .x = -0.5,
            .y = 0.5,
            .z = 0,
            .color = 0xffffffff,
            .u = normFloat(0),
            .v = normFloat(1),
            .nz = 1.0,
        },
    };

    pub const indices = &indicesWithOffset(0);

    pub fn indicesWithOffset(comptime o: comptime_int) [6]u16 {
        return [_]u16{
            o + 0, o + 1, o + 2, o + 0, o + 2, o + 3,
        };
    }
};

pub const cube = struct {
    pub const north_face_verts = &[_]Vertex{
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nz = -1.0 },
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = 0, .nz = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nz = -1.0 },
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = normFloat(1), .nz = -1.0 },
    };

    pub const south_face_verts = &[_]Vertex{
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = 0, .nz = 1 },
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = 0, .nz = 1 },
        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nz = 1 },
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = 0, .v = normFloat(1), .nz = 1 },
    };

    pub const west_face_verts = &[_]Vertex{
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nx = -1.0 },
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = 0, .nx = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nx = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = normFloat(1), .nx = -1.0 },
    };

    pub const east_face_verts = &[_]Vertex{
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nx = 1 },
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = 0, .nx = 1 },
        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nx = 1 },
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = normFloat(1), .nx = 1 },
    };

    pub const bottom_face_verts = &[_]Vertex{
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .ny = -1 },
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = 0, .ny = -1 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .ny = -1 },
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = normFloat(1), .ny = -1 },
    };

    pub const top_face_verts = &[_]Vertex{
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .ny = 1 },
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = 0, .ny = 1 },
        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .ny = 1 },
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = normFloat(1), .ny = 1 },
    };
    pub const vertices = north_face_verts ++
        south_face_verts ++
        west_face_verts ++
        east_face_verts ++
        bottom_face_verts ++
        top_face_verts;

    // cube index buffer
    pub const indices = &(quad.indicesWithOffset(0) ++ // north
        quad.indicesWithOffset(4) ++ // south
        quad.indicesWithOffset(8) ++ // west
        quad.indicesWithOffset(12) ++ // east
        quad.indicesWithOffset(16) ++ // bottom
        quad.indicesWithOffset(20)); // top
};
