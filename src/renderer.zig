const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const tt = @import("stb").truetype;
const zlm = @import("zlm");
const vec3 = zlm.vec3;
const Vec2 = zlm.Vec2;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;
const default_shader = @import("shaders/default.zig");
const normFloat = @import("geom.zig").normFloat;

const Buffer = @import("buffer.zig").Buffer;

pub const Vertex = packed struct { x: f32, y: f32, z: f32, color: u32, u: i16, v: i16 };

pub const DrawOptions = struct {
    tint: u32 = 0xffffffff,
    scale: f32 = 1.0,
};

pub const DrawCall = struct {
    base_element: u32,
    num_elements: u32,
    texture: ?sg.Image = null,
};

pub const Rect = struct {
    pos: Vec2,
    w: f32,
    h: f32,
};

pub const UVRect = struct {
    a: Vec2 = .{ .x = 0, .y = 0 },
    b: Vec2 = .{ .x = 1, .y = 1 },
};

pub const TextureRenderer = struct {
    const Self = @This();

    const MAX_VERTS = 65535;

    verts: Buffer(Vertex, MAX_VERTS) = .{},
    indices: Buffer(u16, 10000) = .{},
    calls: Buffer(DrawCall, 1024) = .{},

    default_texture: sg.Image = .{},

    pub fn init(self: *Self) void {
        var default_img_desc: sg.ImageDesc = .{
            .width = 1,
            .height = 1,
            .pixel_format = .RGBA8,
        };
        default_img_desc.data.subimage[0][0] = sg.asRange([_]u8{
            0xff, 0xff, 0xff, 0xff,
        });
        self.default_texture = sg.makeImage(default_img_desc);
    }

    pub fn begin(self: *Self, mvp: Mat4) void {
        sg.applyUniforms(.VS, 0, sg.asRange(default_shader.VsParams{
            .mvp = mvp,
        }));
        self.verts.reset();
        self.indices.reset();
        self.calls.reset();
    }

    pub fn end(self: *Self) void {
        if (self.indices.items.len == 0) return;
        var bind: sg.Bindings = .{};
        bind.vertex_buffers[0] = sg.makeBuffer(.{
            .usage = .STREAM,
            .size = @sizeOf(Vertex) * 2048,
        });
        defer sg.destroyBuffer(bind.vertex_buffers[0]);
        bind.index_buffer = sg.makeBuffer(.{
            .type = .INDEXBUFFER,
            .usage = .STREAM,
            .size = @sizeOf(Vertex) * 2048,
        });
        defer sg.destroyBuffer(bind.index_buffer);
        sg.updateBuffer(bind.vertex_buffers[0], sg.asRange(self.verts.items));
        sg.updateBuffer(bind.index_buffer, sg.asRange(self.indices.items));
        var current_texture_id: u32 = 0;
        for (self.calls.items) |call| {
            var t = call.texture orelse self.default_texture;
            if (current_texture_id != t.id) {
                bind.fs_images[0] = t;
                sg.applyBindings(bind);
                current_texture_id = t.id;
            }
            sg.draw(call.base_element, call.num_elements, 1);
        }
    }

    pub fn drawRect(self: *Self, r: Rect, opts: DrawOptions) void {
        self.drawRectTextured(r, opts, null);
    }

    pub fn drawRectTextured(self: *Self, r: Rect, opts: DrawOptions, t: ?sg.Image) void {
        self.drawRectTexturedWithUV(r, .{}, opts, t);
    }

    pub fn drawRectTexturedWithUV(self: *Self, r: Rect, uv: UVRect, opts: DrawOptions, t: ?sg.Image) void {
        const vertices = [4]Vertex{
            .{
                .x = r.pos.x,
                .y = r.pos.y,
                .z = 0,
                .color = opts.tint,
                .u = normFloat(uv.a.x),
                .v = normFloat(uv.b.y),
            },
            .{
                .x = r.pos.x + r.w * opts.scale,
                .y = r.pos.y,
                .z = 0,
                .color = opts.tint,
                .u = normFloat(uv.b.x),
                .v = normFloat(uv.b.y),
            },
            .{
                .x = r.pos.x + r.w * opts.scale,
                .y = r.pos.y + r.h * opts.scale,
                .z = 0,
                .color = opts.tint,
                .u = normFloat(uv.b.x),
                .v = normFloat(uv.a.y),
            },
            .{
                .x = r.pos.x,
                .y = r.pos.y + r.h * opts.scale,
                .z = 0,
                .color = opts.tint,
                .u = normFloat(uv.a.x),
                .v = normFloat(uv.a.y),
            },
        };
        var n: u16 = @intCast(u16, self.verts.items.len);
        _ = self.verts.addSlice(&vertices);
        var call: DrawCall = .{
            .base_element = @intCast(u16, self.indices.items.len),
            .num_elements = 6,
            .texture = t,
        };
        _ = self.calls.add(call);
        _ = self.indices.addSlice(&[_]u16{
            n + 0, n + 1, n + 2, n + 0, n + 2, n + 3,
        });
    }
};
