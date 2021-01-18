const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;
const sshape = sokol.shape;

usingnamespace @import("math.zig");
const math = @import("std").math;

const tt = @import("stb").truetype;

const default_shader = @import("shaders/default.zig");
const shapes_shader = @import("shaders/shapes.zig");

const state = struct {
    var mouse_held: bool = false;
    var mouse_x: f32 = 0;
    var mouse_y: f32 = 0;
    const inputs = struct {
        var _held = [_]bool{false} ** blk: {
            var max = 0;
            for (@typeInfo(sapp.Keycode).Enum.fields) |f| {
                if (f.value > max) max = f.value;
            }
            break :blk max;
        };

        fn held(c: sapp.Keycode) bool {
            return _held[@intCast(usize, @enumToInt(c))];
        }
    };
    var pip: sg.Pipeline = .{};
    var bind: sg.Bindings = .{};
    var pass_action: sg.PassAction = .{};
};

const Vertex = packed struct {
    x: f32, y: f32, z: f32, color: u32, u: i16, v: i16
};

const assets_dir = "../assets/";

export fn init() void {
    var ubuntu_32 = tt.Font.init(@embedFile(assets_dir ++ "fonts/Ubuntu-M.ttf"), 32) catch unreachable;
    // font = tt.Font.init(@embedFile("../Comic-Sans.ttf"), 42) catch unreachable;
    const ctx = sgapp.context();
    sg.setup(.{ .context = ctx });

    // shader and pipeline object
    sg.applyViewport(0, 0, sapp.width(), sapp.height(), true);

    // framebuffer clear color
    state.pass_action.colors[0] = .{ .action = .CLEAR, .val = .{ 1.0, 0.92, 0.8, 1.0 } };

    sr.init();
    tr.init(&ubuntu_32);
}

var rotation: f32 = 0;

export fn event(_e: [*c]const sapp.Event) void {
    if (_e == null) return;
    const e = _e.*;
    switch (e.type) {
        .MOUSE_LEAVE => state.mouse_held = false,
        .MOUSE_UP => {
            // switch (e.mouse_button) {
            //     .LEFT => state.mouse_held = false,
            //     else => {},
            // }
        },
        .MOUSE_DOWN => {
            rotation += 1;
            // switch (e.mouse_button) {
            //     .LEFT => {
            //         state.mouse_held = true;
            //     },
            //     else => {},
            // }
        },
        .MOUSE_MOVE => {
            state.mouse_x = e.mouse_x;
            state.mouse_y = e.mouse_y;
        },
        .KEY_DOWN => {
            state.inputs._held[@intCast(usize, @enumToInt(e.key_code))] = true;
        },
        .KEY_UP => {
            state.inputs._held[@intCast(usize, @enumToInt(e.key_code))] = false;
        },
        else => {},
    }
}

fn normFloat(f: f32) i16 {
    return @floatToInt(i16, 32767 * f);
}

const DrawOptions = struct {
    tint: u32 = 0xff000000,
    scale: f32 = 1.0,
};

var sr: SceneRenderer = .{};
var tr: TextRenderer = .{};

fn Buffer(comptime T: type, count: comptime_int) type {
    return struct {
        const Self = @This();
        data: [count]T = undefined,
        items: []const T = &[_]T{},

        fn reset(self: *Self) void {
            self.items.len = 0;
        }

        fn add(self: *Self, item: T) usize {
            std.debug.assert(self.items.len < count);
            self.data[self.items.len] = item;
            self.items = self.data[0 .. self.items.len + 1];
            return self.items.len;
        }

        fn addSlice(self: *Self, items: []const T) usize {
            for (items) |it| _ = self.add(it);
            return self.items.len;
        }
    };
}

const Shape = struct {
    pos: Vec3 = Vec3.zero(),
    draw: sshape.ElementRange = .{},
};

const SceneRenderer = struct {
    const BOX = 0;
    const PLANE = 1;
    const SPHERE = 2;
    const CYLINDER = 3;
    const TORUS = 4;
    const NUM_SHAPES = 5;

    const Self = @This();

    const MAX_VERTS = 65535;

    shapes: [NUM_SHAPES]Shape = undefined,
    // verts: Buffer(Vertex, MAX_VERTS) = .{},
    // indices: Buffer(u16, 10000) = .{},
    pip: sg.Pipeline = .{},
    bind: sg.Bindings = .{},
    view: Mat4 = Mat4.lookat(.{ .x = 0.0, .y = 0, .z = 6.0 }, Vec3.zero(), Vec3.up()),
    vs_params: shapes_shader.VsParams = undefined,

    fn init(self: *Self) void {
        // shader- and pipeline-object
        var pip_desc: sg.PipelineDesc = .{
            .shader = sg.makeShader(shapes_shader.desc()),
            .index_type = .UINT16,
            .depth_stencil = .{
                .depth_compare_func = .LESS_EQUAL,
                .depth_write_enabled = true,
            },
            .rasterizer = .{
                .cull_mode = .NONE,
            },
        };
        pip_desc.layout.buffers[0] = sshape.bufferLayoutDesc();
        pip_desc.layout.attrs[0] = sshape.positionAttrDesc();
        pip_desc.layout.attrs[1] = sshape.normalAttrDesc();
        pip_desc.layout.attrs[2] = sshape.texcoordAttrDesc();
        pip_desc.layout.attrs[3] = sshape.colorAttrDesc();
        self.pip = sg.makePipeline(pip_desc);

        // shape positions
        self.shapes[BOX].pos = .{ .x = -1, .y = 1, .z = 0 };
        self.shapes[PLANE].pos = .{ .x = 1, .y = 1, .z = 0 };
        self.shapes[SPHERE].pos = .{ .x = -2, .y = -1, .z = 0 };
        self.shapes[CYLINDER].pos = .{ .x = 2, .y = -1, .z = 0 };
        self.shapes[TORUS].pos = .{ .x = 0, .y = -1, .z = 0 };

        // generate shape geometries
        var vertices: [6 * 1024]sshape.Vertex = undefined;
        var indices: [16 * 1024]u16 = undefined;
        var buf: sshape.Buffer = .{
            .vertices = .{ .buffer = sshape.asRange(vertices) },
            .indices = .{ .buffer = sshape.asRange(indices) },
        };
        buf = sshape.buildBox(buf, .{
            .width = 1.0,
            .height = 1.0,
            .depth = 1.0,
            .tiles = 10,
            .random_colors = true,
        });
        self.shapes[BOX].draw = sshape.elementRange(buf);
        buf = sshape.buildPlane(buf, .{
            .width = 1.0,
            .depth = 1.0,
            .tiles = 10,
            .random_colors = true,
        });
        self.shapes[PLANE].draw = sshape.elementRange(buf);
        buf = sshape.buildSphere(buf, .{
            .radius = 0.75,
            .slices = 36,
            .stacks = 20,
            .random_colors = true,
        });
        self.shapes[SPHERE].draw = sshape.elementRange(buf);
        buf = sshape.buildCylinder(buf, .{
            .radius = 0.5,
            .height = 1.5,
            .slices = 36,
            .stacks = 10,
            .random_colors = true,
        });
        self.shapes[CYLINDER].draw = sshape.elementRange(buf);
        buf = sshape.buildTorus(buf, .{
            .radius = 0.5,
            .ring_radius = 0.3,
            .rings = 36,
            .sides = 18,
            .random_colors = true,
        });
        self.shapes[TORUS].draw = sshape.elementRange(buf);
        std.debug.assert(buf.valid);

        // one vertex- and index-buffer for all shapes
        self.bind.vertex_buffers[0] = sg.makeBuffer(sshape.vertexBufferDesc(buf));
        self.bind.index_buffer = sg.makeBuffer(sshape.indexBufferDesc(buf));
    }

    fn render(self: *Self) void {
        const proj = Mat4.persp(60.0, sapp.widthf() / sapp.heightf(), 0.01, 100.0);
        const view_proj = Mat4.mul(proj, self.view);

        sg.applyPipeline(self.pip);
        sg.applyBindings(self.bind);
        for (self.shapes) |shape| {
            // per-shape model-view-projection matrix
            // const model = mat4.mul(mat4.translate(shape.pos), rm);
            const model = Mat4.translate(shape.pos);
            self.vs_params.mvp = Mat4.mul(view_proj, model);
            sg.applyUniforms(.VS, 0, sg.asRange(self.vs_params));
            sg.draw(shape.draw.base_element, shape.draw.num_elements, 1);
        }
    }
};

const TextRenderer = struct {
    const Self = @This();

    const MAX_VERTS = 65535;

    verts: Buffer(Vertex, MAX_VERTS) = .{},
    indices: Buffer(u16, 10000) = .{},
    pip: sg.Pipeline = .{},
    bind: sg.Bindings = .{},
    font: *tt.Font = undefined,

    fn init(self: *Self, f: *tt.Font) void {
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

    fn begin(self: *Self) void {
        sg.applyPipeline(self.pip);
        sg.applyUniforms(.VS, 0, sg.asRange(default_shader.VsParams{
            .mvp = Mat4.ortho(0, sapp.widthf(), 0, sapp.heightf(), -1, 1),
        }));
        self.verts.reset();
        self.indices.reset();
    }

    fn end(self: *Self) void {
        if (self.indices.items.len == 0) return;
        sg.updateBuffer(self.bind.vertex_buffers[0], sg.asRange(self.verts.items));
        sg.updateBuffer(self.bind.index_buffer, sg.asRange(self.indices.items));
        sg.applyBindings(self.bind);
        sg.draw(0, @intCast(u32, self.indices.items.len), 1);
    }

    fn drawString(self: *Self, s: []const u8, pos: Vec2, opts: DrawOptions) void {
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

export fn frame() void {
    if (state.inputs.held(.S)) sr.view = Mat4.mul(Mat4.translate(.{ .x = 0, .y = 0, .z = -0.05 }), sr.view);
    if (state.inputs.held(.W)) sr.view = Mat4.mul(Mat4.translate(.{ .x = 0, .y = 0, .z = 0.05 }), sr.view);
    if (state.inputs.held(.Q)) sr.view = Mat4.mul(Mat4.translate(.{ .x = 0.05, .y = 0, .z = 0 }), sr.view);
    if (state.inputs.held(.E)) sr.view = Mat4.mul(Mat4.translate(.{ .x = -0.05, .y = 0, .z = 0 }), sr.view);
    if (state.inputs.held(.A)) sr.view = Mat4.mul(Mat4.rotate(-0.5, .{ .x = 0, .y = 1, .z = 0 }), sr.view);
    if (state.inputs.held(.D)) sr.view = Mat4.mul(Mat4.rotate(0.5, .{ .x = 0, .y = 1, .z = 0 }), sr.view);

    sg.beginDefaultPass(state.pass_action, sapp.width(), sapp.height());

    // render scene
    //
    sr.render();

    // render UI (ortho)
    //
    tr.begin();
    const s = "123 test this stuff";
    tr.drawString(s, .{ .x = 50, .y = @intToFloat(f32, sapp.height()) / 2 }, .{});
    tr.drawString("yo big boi", .{ .x = 0, .y = sapp.heightf() / 2 + 50 }, .{ .tint = 0xff0000ff });
    tr.end();

    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sg.shutdown();
}

pub fn main() void {
    // var ctx = try fons.Context.init(.{});
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .sample_count = 4,
        .window_title = "stb_truetype test",
    });
}
