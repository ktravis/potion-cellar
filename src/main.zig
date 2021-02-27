const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;
const sshape = sokol.shape;
const stime = sokol.time;
const tt = @import("stb").truetype;
const stbi = @import("stb").image;

const text = @import("text.zig");
const Buffer = @import("buffer.zig").Buffer;
usingnamespace @import("math.zig");
const math = @import("std").math;

const wobj = @import("wavefront-obj");

const default_shader = @import("shaders/default.zig");
const object_shader = @import("shaders/object.zig");

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

const assets_dir = "../assets/";

fn makeTexture(img_data: []const u8) sg.Image {
    var ii = stbi.loadFromMemory(img_data, 4);
    var img_desc: sg.ImageDesc = .{
        .width = @intCast(i32, ii.w),
        .height = @intCast(i32, ii.h),
    };
    img_desc.data.subimage[0][0] = sg.asRange(ii.data);
    return sg.makeImage(img_desc);
}

fn loadObjModelFromFile(alloc: *std.mem.Allocator, path: []const u8) !Mesh {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const model = try wobj.load(alloc, file.reader());

    var verts = std.ArrayList(Vertex).init(alloc);
    defer verts.deinit();
    try verts.ensureCapacity(1000);
    var inds = std.ArrayList(u16).init(alloc);
    defer inds.deinit();
    try inds.ensureCapacity(1000);
    for (model.faces) |f, i| {
        for (f.vertices) |v| {
            var o: Vertex = .{
                .x = model.positions[v.position].x,
                .y = model.positions[v.position].y,
                .z = model.positions[v.position].z,
                .color = 0xffffffff,
                .u = normFloat(0),
                .v = normFloat(0),
            };
            if (v.normal) |n| {
                o.nx = model.normals[n].x;
                o.ny = model.normals[n].y;
                o.nz = model.normals[n].z;
            }
            _ = try inds.append(@intCast(u16, verts.items.len));
            _ = try verts.append(o);
        }
    }
    return sr.loadMesh(verts.items, inds.items);
}

export fn init() void {
    stime.setup();
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

    stbi.setFlipVerticallyOnLoad(true);

    const quad_mesh = sr.loadMesh(quad.vertices, quad.indices);
    var floor_transform = Mat4.identity();
    floor_transform.scale(100);
    floor_transform = Mat4.mul(Mat4.rotate(-90, .{ .x = 1, .y = 0, .z = 0 }), floor_transform);
    _ = sr.objs.add(.{
        .mesh = quad_mesh,
        .texture = makeTexture(@embedFile(assets_dir ++ "images/test.png")),
        .transform = floor_transform,
        .pos = .{ .x = 0, .y = 0, .z = 0 },
    });

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = &arena.allocator;

    const statue = loadObjModelFromFile(alloc, "assets/models/statue_head.obj") catch {
        @panic("failed loading cactus");
    };
    const red_texture = blk: {
        var img_desc: sg.ImageDesc = .{
            .width = 1,
            .height = 1,
        };
        img_desc.data.subimage[0][0] = sg.asRange(&[_]u8{ 0xaa, 0xaa, 0xaa, 0xff });
        break :blk sg.makeImage(img_desc);
    };

    const cube_mesh = sr.loadMesh(cube.vertices, cube.indices);
    var cube_transform = Mat4.identity();
    cube_transform.scale(1);
    _ = sr.objs.add(.{
        .mesh = statue,
        .texture = red_texture,
        .transform = cube_transform,
        .pos = .{ .x = 1, .y = 1, .z = -6 },
    });

    var quad_transform = Mat4.identity();
    quad_transform.scale(2);
    _ = sr.objs.add(.{
        .mesh = quad_mesh,
        .transform = quad_transform,
        .pos = .{ .x = 0, .y = 1, .z = -10 },
    });
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
            if (e.key_code == .ESCAPE) {
                sapp.quit();
            }
            state.inputs._held[@intCast(usize, @enumToInt(e.key_code))] = true;
        },
        .KEY_UP => {
            state.inputs._held[@intCast(usize, @enumToInt(e.key_code))] = false;
        },
        else => {},
    }
}

var sr: SceneRenderer = .{};
var tr: text.Renderer = .{};

const quad = struct {
    const vertices = &[_]Vertex{
        .{
            .x = -0.5,
            .y = -0.5,
            .z = 0,
            .color = 0x00ffffff,
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
    const indices = &[_]u16{
        0, 1, 2, 0, 2, 3,
    };
};

const cube = struct {
    const vertices = &[_]Vertex{
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nz = -1.0 },
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = 0, .nz = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nz = -1.0 },
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = normFloat(1), .nz = -1.0 },

        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nz = 1 },
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = 0, .nz = 1 },
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = 0, .nz = 1 },
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = 0, .v = normFloat(1), .nz = 1 },

        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nx = -1.0 },
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = 0, .nx = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nx = -1.0 },
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = normFloat(1), .nx = -1.0 },

        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .nx = 1 },
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = normFloat(1), .v = 0, .nx = 1 },
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .nx = 1 },
        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = 0, .v = normFloat(1), .nx = 1 },

        .{ .x = 0.5, .y = -0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .ny = -1 },
        .{ .x = -0.5, .y = -0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = 0, .ny = -1 },
        .{ .x = -0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .ny = -1 },
        .{ .x = 0.5, .y = -0.5, .z = -0.5, .color = white, .u = 0, .v = normFloat(1), .ny = -1 },

        .{ .x = 0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = normFloat(1), .ny = 1 },
        .{ .x = -0.5, .y = 0.5, .z = 0.5, .color = white, .u = normFloat(1), .v = 0, .ny = 1 },
        .{ .x = -0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = 0, .ny = 1 },
        .{ .x = 0.5, .y = 0.5, .z = -0.5, .color = white, .u = 0, .v = normFloat(1), .ny = 1 },
    };

    // cube index buffer
    const indices = &[_]u16{
        0,  1,  2,  0,  2,  3,
        6,  5,  4,  7,  6,  4,
        8,  9,  10, 8,  10, 11,
        14, 13, 12, 15, 14, 12,
        16, 17, 18, 16, 18, 19,
        22, 21, 20, 23, 22, 20,
    };
};

const white = 0xffffffff;

// a vertex struct with position, color and uv-coords
pub const Vertex = packed struct {
    x: f32,
    y: f32,
    z: f32,
    color: u32,
    u: i16,
    v: i16,
    nx: f32 = 0,
    ny: f32 = 0,
    nz: f32 = 0,
};

const Shape = struct {
    pos: Vec3 = Vec3.zero(),
    draw: sshape.ElementRange = .{},
};

const Mesh = struct {
    base_element: u32,
    num_elements: u32,
};

const Object = struct {
    mesh: Mesh,
    texture: ?sg.Image = null,

    pos: Vec3 = Vec3.zero(),
    transform: Mat4 = Mat4.identity(),
    vs_params: object_shader.VsParams = undefined,
};

const Camera = struct {
    pos: Vec3 = .{ .x = 0.0, .y = 1, .z = 0.0 },
    dir: Vec3 = .{ .x = 0.0, .y = 0, .z = 1.0 },
    up: Vec3 = Vec3.up(),

    pub fn view(self: Camera) Mat4 {
        return Mat4.lookat(self.pos, self.pos.sub(self.dir), self.up);
    }
};

const SceneRenderer = struct {
    const Self = @This();

    const MAX_VERTS = 65535;
    objs: Buffer(Object, MAX_VERTS) = .{},
    verts: Buffer(Vertex, MAX_VERTS) = .{},
    indices: Buffer(u16, 10000) = .{},
    new_mesh_data: bool = false,
    pip: sg.Pipeline = .{},
    bind: sg.Bindings = .{},
    camera: Camera = .{},
    vs_params: object_shader.VsParams = undefined,
    default_texture: sg.Image = .{},

    fn init(self: *Self) void {
        // shader- and pipeline-object
        var pip_desc: sg.PipelineDesc = .{
            .shader = sg.makeShader(object_shader.desc()),
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
            .rasterizer = .{
                .cull_mode = .BACK,
                .face_winding = .CCW,
                // .cull_mode = .NONE,
            },
        };
        pip_desc.layout.attrs[0].format = .FLOAT3;
        pip_desc.layout.attrs[1].format = .UBYTE4N;
        pip_desc.layout.attrs[2].format = .SHORT2N;
        pip_desc.layout.attrs[3].format = .FLOAT3;
        self.pip = sg.makePipeline(pip_desc);

        // a checkerboard texture
        const img_width = 8;
        const img_height = 8;
        const pixels = init: {
            var res: [img_width][img_height]u32 = undefined;
            var y: usize = 0;
            while (y < img_height) : (y += 1) {
                var x: usize = 0;
                while (x < img_width) : (x += 1) {
                    res[y][x] = if (0 == (y ^ x) & 1) 0xFF_00_00_00 else 0xFF_FF_FF_FF;
                }
            }
            break :init res;
        };
        var img_desc: sg.ImageDesc = .{
            .width = img_width,
            .height = img_height,
        };
        // FIXME: https://github.com/ziglang/zig/issues/6068
        img_desc.data.subimage[0][0] = sg.asRange(pixels);
        self.default_texture = sg.makeImage(img_desc);
        self.bind.fs_images[0] = self.default_texture;

        self.bind.vertex_buffers[0] = sg.makeBuffer(.{
            .usage = .STREAM,
            .size = 6 * 4096,
        });
        self.bind.index_buffer = sg.makeBuffer(.{
            .type = .INDEXBUFFER,
            .usage = .STREAM,
            .size = 6 * 4096,
        });
    }

    fn loadMesh(self: *Self, verts: []const Vertex, indices: []const u16) Mesh {
        var m = Mesh{
            .base_element = @intCast(u32, self.indices.items.len),
            .num_elements = @intCast(u32, indices.len),
        };
        const n = @intCast(u16, self.verts.items.len);
        _ = self.verts.addSlice(verts);
        for (indices) |i| {
            _ = self.indices.add(n + i);
        }
        self.new_mesh_data = true;
        return m;
    }

    fn drawMesh(self: *Self, m: Mesh, vs_params: object_shader.VsParams) void {
        sg.applyUniforms(.VS, 0, sg.asRange(vs_params));
        sg.draw(m.base_element, m.num_elements, 1);
    }

    fn render(self: *Self) void {
        if (self.new_mesh_data) {
            sg.updateBuffer(self.bind.vertex_buffers[0], sg.asRange(self.verts.items));
            sg.updateBuffer(self.bind.index_buffer, sg.asRange(self.indices.items));
            self.new_mesh_data = false;
        }
        sg.applyPipeline(self.pip);

        self.objs.items[1].transform = Mat4.mul(Mat4.rotate(0.5, Vec3.up()), self.objs.items[1].transform);
        self.objs.items[1].transform = Mat4.mul(Mat4.rotate(0.1, .{ .x = -1, .y = 0, .z = 0 }), self.objs.items[1].transform);

        const proj = Mat4.persp(60.0, sapp.widthf() / sapp.heightf(), 0.01, 100.0);
        const view_proj = Mat4.mul(proj, self.camera.view());

        for (self.objs.items) |obj| {
            self.bind.fs_images[0] = obj.texture orelse self.default_texture;
            sg.applyBindings(self.bind);
            var vs_params = obj.vs_params;
            vs_params.model = Mat4.mul(Mat4.translate(obj.pos), obj.transform);
            vs_params.view = self.camera.view();
            vs_params.view_pos = self.camera.pos;
            vs_params.projection = proj;
            // vs_params.light_pos = .{ .x = 0, .y = 20, .z = 0 };
            self.drawMesh(obj.mesh, vs_params);
        }
    }
};

const target_frametime = 8.33;
var last_time: u64 = 0;

export fn frame() void {
    const now = stime.now();
    const x = now - last_time;
    if (stime.ms(x) < target_frametime) {
        const ns = (target_frametime - stime.ms(x)) * 1_000_000;
        std.time.sleep(@floatToInt(u64, ns));
    }
    last_time = now;

    if (state.inputs.held(.S)) {
        const o = sr.camera.dir.norm().scale(0.1);
        sr.camera.pos = sr.camera.pos.add(o);
    }
    if (state.inputs.held(.W)) {
        const o = sr.camera.dir.norm().scale(-0.1);
        sr.camera.pos = sr.camera.pos.add(o);
    }
    if (state.inputs.held(.Q)) {
        const o = sr.camera.dir.norm().cross(sr.camera.up).scale(0.1);
        sr.camera.pos = sr.camera.pos.add(o);
    }
    if (state.inputs.held(.E)) {
        const o = sr.camera.dir.norm().cross(sr.camera.up).scale(-0.1);
        sr.camera.pos = sr.camera.pos.add(o);
    }
    if (state.inputs.held(.A)) {
        const camt = math.cos(@as(f32, -0.02));
        const samt = math.sin(@as(f32, -0.02));
        sr.camera.dir = .{ .x = sr.camera.dir.x * camt - sr.camera.dir.z * samt, .y = 0, .z = sr.camera.dir.x * samt + sr.camera.dir.z * camt };
    }
    if (state.inputs.held(.D)) {
        const camt = math.cos(@as(f32, 0.02));
        const samt = math.sin(@as(f32, 0.02));
        sr.camera.dir = .{ .x = sr.camera.dir.x * camt - sr.camera.dir.z * samt, .y = 0, .z = sr.camera.dir.x * samt + sr.camera.dir.z * camt };
    }

    sg.beginDefaultPass(state.pass_action, sapp.width(), sapp.height());

    // render scene
    //
    sr.render();

    // render UI (ortho)
    //
    tr.begin(sapp.widthf(), sapp.heightf());
    var buf: [256]u8 = undefined;
    tr.drawString(std.fmt.bufPrint(&buf, "pos: [{}]", .{sr.camera.pos}) catch "error", .{ .x = 8, .y = 28 }, .{});
    tr.end();

    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sg.shutdown();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .sample_count = 4,
        .window_title = "potion cellar",
    });
}
