const sokol = @import("sokol");
const sg = sokol.gfx;
const tt = @import("stb").truetype;
usingnamespace @import("math.zig");
const default_shader = @import("shaders/default.zig");

const Buffer = @import("buffer.zig").Buffer;

pub const Vertex = packed struct {
    x: f32, y: f32, z: f32, color: u32, u: i16, v: i16
};

pub const DrawOptions = struct {
    tint: u32 = 0xff000000,
    scale: f32 = 1.0,
};

pub const Renderer = struct {
    const Self = @This();

    const MAX_VERTS = 65535;

    verts: Buffer(Vertex, MAX_VERTS) = .{},
    indices: Buffer(u16, 10000) = .{},
    pip: sg.Pipeline = .{},

    bind: sg.Bindings = .{},
    font: *tt.Font = undefined,

    // const model = mat4.mul(mat4.translate(shape.pos), rm);

    pub fn init(self: *Self, f: *tt.Font) void {
        const quadShader = sg.makeShader(default_shader.desc());
        var pip_desc: sg.PipelineDesc = .{
            .shader = quadShader,
            .index_type = .UINT16,
            .blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
            },
            .depth_stencil = .{
                .depth_compare_func = .LESS_EQUAL,
                .depth_write_enabled = true,
            },
            .rasterizer = .{ .cull_mode = .BACK },
        };
        pip_desc.layout.attrs[0].format = .FLOAT3;
        pip_desc.layout.attrs[1].format = .UBYTE4N;
        pip_desc.layout.attrs[2].format = .SHORT2N;
        self.pip = sg.makePipeline(pip_desc);

        var img_desc: sg.ImageDesc = .{
            .width = tt.Font.WIDTH,
            .height = tt.Font.HEIGHT,
            .pixel_format = .RGBA8,
        };
        img_desc.data.subimage[0][0] = sg.asRange(f.tex);
        self.bind.fs_images[0] = sg.makeImage(img_desc);

        self.bind.vertex_buffers[0] = sg.makeBuffer(.{
            .usage = .STREAM,
            .size = 6 * 2048,
        });

        self.bind.index_buffer = sg.makeBuffer(.{
            .type = .INDEXBUFFER,
            .usage = .STREAM,
            .size = 6 * 2048,
        });

        self.font = f;
    }

    pub fn begin(self: *Self, w: f32, h: f32) void {
        sg.applyPipeline(self.pip);
        sg.applyUniforms(.VS, 0, sg.asRange(default_shader.VsParams{
            .mvp = Mat4.ortho(0, w, 0, h, -1, 1),
        }));
        self.verts.reset();
        self.indices.reset();
    }

    pub fn end(self: *Self) void {
        if (self.indices.items.len == 0) return;
        sg.updateBuffer(self.bind.vertex_buffers[0], sg.asRange(self.verts.items));
        sg.updateBuffer(self.bind.index_buffer, sg.asRange(self.indices.items));
        sg.applyBindings(self.bind);
        sg.draw(0, @intCast(u32, self.indices.items.len), 1);
    }

    pub fn drawString(self: *Self, s: []const u8, pos: Vec2, opts: DrawOptions) void {
        var n: u16 = @intCast(u16, self.verts.items.len);
        var xoff: f32 = 0;
        var yoff: f32 = 0;
        for (s) |c, i| {
            if (c == '\n') {
                xoff = 0;
                yoff += self.font.line_height * opts.scale;
                continue;
            }
            var q = self.font.getBakedQuad(c);
            if (c != ' ' and c != '\t') {
                const vertices = [4]Vertex{
                    .{
                        .x = pos.x + xoff + q.x0 * opts.scale,
                        .y = pos.y + yoff + q.y0 * opts.scale,
                        .z = 0,
                        .color = opts.tint,
                        .u = normFloat(q.s0),
                        .v = normFloat(q.t0),
                    },
                    .{
                        .x = pos.x + xoff + q.x1 * opts.scale,
                        .y = pos.y + yoff + q.y0 * opts.scale,
                        .z = 0,
                        .color = opts.tint,
                        .u = normFloat(q.s1),
                        .v = normFloat(q.t0),
                    },
                    .{
                        .x = pos.x + xoff + q.x1 * opts.scale,
                        .y = pos.y + yoff + q.y1 * opts.scale,
                        .z = 0,
                        .color = opts.tint,
                        .u = normFloat(q.s1),
                        .v = normFloat(q.t1),
                    },
                    .{
                        .x = pos.x + xoff + q.x0 + opts.scale,
                        .y = pos.y + yoff + q.y1 * opts.scale,
                        .z = 0,
                        .color = opts.tint,
                        .u = normFloat(q.s0),
                        .v = normFloat(q.t1),
                    },
                };
                _ = self.verts.addSlice(&vertices);
                _ = self.indices.addSlice(&[_]u16{
                    n + 0, n + 1, n + 2, n + 2, n + 3, n + 0,
                });
                n += @intCast(u16, vertices.len);
            }
            xoff += q.x_advance * opts.scale;
        }
    }
};
