const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;

const Buffer = @import("buffer.zig").Buffer;
usingnamespace @import("geom.zig");
// usingnamespace @import("math.zig");
const zlm = @import("zlm");
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;

const object_shader = @import("shaders/object.zig");

pub const Shape = struct {
    pos: Vec3 = Vec3.zero(),
    draw: sshape.ElementRange = .{},
};

pub const Mesh = struct {
    base_element: u32,
    num_elements: u32,
};

pub const Object = struct {
    mesh: Mesh,
    texture: ?sg.Image = null,

    pos: Vec3 = Vec3.zero(),
    transform: Mat4 = Mat4.identity(),
    vs_params: object_shader.VsParams = undefined,
};

pub const Camera = struct {
    pos: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    dir: Vec3 = .{ .x = 0.0, .y = 0, .z = 1.0 },
    up: Vec3 = vec3(0, 1, 0),

    pub fn view(self: Camera) Mat4 {
        return Mat4.createLook(self.pos, self.dir, self.up);
    }
};

pub const SceneRenderer = struct {
    const Self = @This();

    const FOV = zlm.toRadians(60.0);
    const NEAR = 0.01;
    const FAR = 100.0;
    const MAX_VERTS = 65535;
    const MAX_LIGHTS = 8;

    objs: Buffer(Object, MAX_VERTS) = .{},
    verts: Buffer(Vertex, MAX_VERTS) = .{},
    indices: Buffer(u16, 10000) = .{},
    new_mesh_data: bool = false,
    pip: sg.Pipeline = .{},
    bind: sg.Bindings = .{},
    camera: Camera = .{},
    vs_params: object_shader.VsParams = undefined,
    default_texture: sg.Image = .{},
    lights: Buffer(object_shader.PointLight, MAX_LIGHTS) = .{},

    pub fn init(self: *Self) void {
        // shader- and pipeline-object
        var pip_desc: sg.PipelineDesc = .{
            .shader = sg.makeShader(object_shader.desc()),
            .index_type = .UINT16,
            .depth = .{
                .compare = .LESS_EQUAL,
                .write_enabled = true,
            },
            .cull_mode = .BACK,
            .face_winding = .CCW,
        };
        pip_desc.layout.attrs[0].format = .FLOAT3;
        pip_desc.layout.attrs[1].format = .UBYTE4N;
        pip_desc.layout.attrs[2].format = .SHORT2N;
        pip_desc.layout.attrs[3].format = .FLOAT3;
        pip_desc.colors[0].blend = .{
            .enabled = true,
            .src_factor_rgb = .SRC_ALPHA,
            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        };
        pip_desc.depth.pixel_format = .DEPTH;

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
            .wrap_u = .CLAMP_TO_EDGE,
            .wrap_v = .CLAMP_TO_EDGE,
        };
        // FIXME: https://github.com/ziglang/zig/issues/6068
        img_desc.data.subimage[0][0] = sg.asRange(pixels);
        self.default_texture = sg.makeImage(img_desc);
        self.bind.fs_images[0] = self.default_texture;

        self.bind.vertex_buffers[0] = sg.makeBuffer(.{
            .usage = .STREAM,
            .size = 6 * 8192 * 5,
        });
        self.bind.index_buffer = sg.makeBuffer(.{
            .type = .INDEXBUFFER,
            .usage = .STREAM,
            .size = 6 * 8192 * 5,
        });

        _ = self.lights.add(.{
            .pos = .{ .x = 0, .y = 10, .z = 5 },
        });
        _ = self.lights.add(.{
            .pos = .{ .x = -4, .y = 1, .z = 8 },
            // .color = .{ .x = 1, .y = 0, .z = 0 },
        });
    }

    pub fn loadMesh(self: *Self, verts: []const Vertex, indices: []const u16) Mesh {
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

    pub fn drawMesh(self: *Self, m: Mesh, vs_params: object_shader.VsParams) void {
        sg.applyUniforms(.VS, 0, sg.asRange(vs_params));
        sg.draw(m.base_element, m.num_elements, 1);
    }

    pub fn render(self: *Self) void {
        if (self.new_mesh_data) {
            sg.updateBuffer(self.bind.vertex_buffers[0], sg.asRange(self.verts.items));
            sg.updateBuffer(self.bind.index_buffer, sg.asRange(self.indices.items));
            self.new_mesh_data = false;
        }
        sg.applyPipeline(self.pip);

        self.lights.items[0].pos = self.camera.pos;

        const proj = Mat4.createPerspective(Self.FOV, sapp.widthf() / sapp.heightf(), Self.NEAR, Self.FAR);

        for (self.objs.items) |obj| {
            self.bind.fs_images[0] = obj.texture orelse self.default_texture;
            sg.applyBindings(self.bind);
            var vs_params = obj.vs_params;
            vs_params.model = Mat4.mul(Mat4.createTranslation(obj.pos), obj.transform);
            vs_params.view = self.camera.view();
            vs_params.view_pos = self.camera.pos;
            vs_params.projection = proj;
            vs_params.num_lights = @intToFloat(f32, self.lights.items.len);
            for (self.lights.items) |l, i| {
                vs_params.lights[i] = l;
            }
            // vs_params.light_pos = .{ .x = 0, .y = 20, .z = 0 };
            self.drawMesh(obj.mesh, vs_params);
        }
    }
};
