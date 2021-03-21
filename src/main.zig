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
const TextureRenderer = @import("renderer.zig").TextureRenderer;
const Buffer = @import("buffer.zig").Buffer;
usingnamespace @import("geom.zig");
usingnamespace @import("level.zig");
usingnamespace @import("scene.zig");
const math = @import("std").math;

const zlm = @import("zlm");
const vec2 = zlm.vec2;
const Vec2 = zlm.Vec2;
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;

const wobj = @import("wavefront-obj");

const default_shader = @import("shaders/default.zig");

const sample_count = 1;

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

        fn heldOnce(c: sapp.Keycode) bool {
            var h = _held[@intCast(usize, @enumToInt(c))];
            _held[@intCast(usize, @enumToInt(c))] = false;
            return h;
        }
    };
    var pip: sg.Pipeline = .{};
    var offscreen_pip: sg.Pipeline = .{};
    var bind: sg.Bindings = .{};
    var pass_action: sg.PassAction = .{};
    var opa: sg.PassAction = .{};
};

const assets_dir = "../assets/";

fn makeImageTexture(img_data: []const u8) sg.Image {
    var ii = stbi.loadFromMemory(img_data, 4);
    var img_desc: sg.ImageDesc = .{
        .width = @intCast(i32, ii.w),
        .height = @intCast(i32, ii.h),
        .wrap_u = .CLAMP_TO_EDGE,
        .wrap_v = .CLAMP_TO_EDGE,
    };
    img_desc.data.subimage[0][0] = sg.asRange(ii.data);
    return sg.makeImage(img_desc);
}

fn loadObjModelFromFile(alloc: *std.mem.Allocator, path: []const u8) !Mesh {
    var mat_path = try alloc.dupe(u8, path);
    _ = std.mem.replace(u8, path, ".obj", ".mtl", mat_path);
    var mat_file = try std.fs.cwd().openFile(mat_path, .{});
    defer mat_file.close();
    const matLib = try wobj.loadMaterials(alloc, mat_file.reader());

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const model = try wobj.load(alloc, file.reader());

    var verts = std.ArrayList(Vertex).init(alloc);
    defer verts.deinit();
    try verts.ensureCapacity(1000);
    var inds = std.ArrayList(u16).init(alloc);
    defer inds.deinit();
    try inds.ensureCapacity(1000);
    for (model.objects) |o| {
        var color: u32 = white;
        if (o.material) |m| {
            if (matLib.materials.get(m)) |found| {
                if (found.diffuse_color) |col| {
                    color = @floatToInt(u32, 0xff * col.r) << 0 |
                        @floatToInt(u32, 0xff * col.g) << 8 |
                        @floatToInt(u32, 0xff * col.b) << 16 |
                        0xff << 24;
                }
            }
        }
        for (model.faces[o.start .. o.start + o.count]) |f| {
            for (f.vertices) |v| {
                var vert: Vertex = .{
                    .x = model.positions[v.position].x,
                    .y = model.positions[v.position].y,
                    .z = model.positions[v.position].z,
                    .color = color,
                };
                if (v.normal) |n| {
                    vert.nx = model.normals[n].x;
                    vert.ny = model.normals[n].y;
                    vert.nz = model.normals[n].z;
                }
                _ = try inds.append(@intCast(u16, verts.items.len));
                _ = try verts.append(vert);
            }
        }
    }
    return sr.loadMesh(verts.items, inds.items);
}

const levelString =
    \\oooooooooooooooo
    \\o..............o
    \\o..............o
    \\o...oooooooo...o
    \\o...o.....oo...o
    \\o...o.....oo...o
    \\o...ooo..ooo...o
    \\o..............o
    \\oooo...........o
    \\o..............o
    \\o..............o
    \\o..............o
    \\o..............o
    \\o..............o
    \\o..............o
    \\o......oo......o
    \\o......oo..oo..o
    \\o..........oo..o
    \\o..............o
    \\o..............o
    \\o..............o
    \\o..............o
    \\o..............o
    \\o......oo......o
    \\o......oo..oo..o
    \\o..........oo..o
    \\o..............o
    \\oooooooooooooooo
;

var tree: *Object = undefined;

var level: Level = .{};

const player = struct {
    var height: f32 = 0.8;

    var coord: Level.Coord = .{
        .x = 2,
        .y = 2,
    };
    var facing: enum {
        NORTH,
        EAST,
        SOUTH,
        WEST,
    } = .NORTH;
};

var map_pass: sg.Pass = .{};
var render_pass: sg.Pass = .{};
var map_open = false;

export fn init() void {
    // parse the level
    stime.setup();
    var ubuntu_32 = tt.Font.init(@embedFile(assets_dir ++ "fonts/Ubuntu-M.ttf"), 72) catch unreachable;
    // font = tt.Font.init(@embedFile("../Comic-Sans.ttf"), 42) catch unreachable;
    const ctx = sgapp.context();
    sg.setup(.{ .context = ctx });

    // shader and pipeline object
    sg.applyViewport(0, 0, sapp.width(), sapp.height(), true);

    // framebuffer clear color
    state.pass_action.colors[0] = .{ .action = .CLEAR, .value = .{ .r = 1.0, .g = 0.92, .b = 0.8, .a = 1.0 } };
    state.opa.colors[0] = .{ .action = .CLEAR, .value = .{ .r = 1.0, .g = 0, .b = 1, .a = 1.0 } };

    {
        const defaultShader = sg.makeShader(default_shader.desc());
        var pip_desc: sg.PipelineDesc = .{
            .shader = defaultShader,
            .index_type = .UINT16,
            .depth = .{
                .compare = .LESS_EQUAL,
                .write_enabled = true,
            },
            .cull_mode = .BACK,
        };
        pip_desc.colors[0].pixel_format = .RGBA8;
        pip_desc.colors[0].blend = .{
            .enabled = true,
            .src_factor_rgb = .SRC_ALPHA,
            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
            .src_factor_alpha = .SRC_ALPHA,
            .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
        };
        pip_desc.layout.attrs[0].format = .FLOAT3;
        pip_desc.layout.attrs[1].format = .UBYTE4N;
        pip_desc.layout.attrs[2].format = .SHORT2N;
        state.pip = sg.makePipeline(pip_desc);
        pip_desc.depth.pixel_format = .DEPTH;
        state.offscreen_pip = sg.makePipeline(pip_desc);
    }

    sr.init();
    textRenderer.init(&ubuntu_32);
    r.init();

    stbi.setFlipVerticallyOnLoad(true);

    const quad_mesh = sr.loadMesh(quad.vertices, quad.indices);
    var floor_transform = Mat4.createUniformScale(120);
    floor_transform = Mat4.mul(Mat4.createAngleAxis(.{ .x = 1, .y = 0, .z = 0 }, zlm.toRadians(90.0)), floor_transform);
    _ = sr.objs.add(.{
        .mesh = quad_mesh,
        .texture = makeImageTexture(@embedFile(assets_dir ++ "images/test.png")),
        .transform = floor_transform,
        .pos = .{ .x = 0, .y = 0, .z = 0 },
    });

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = &arena.allocator;

    const statue = loadObjModelFromFile(alloc, "assets/models/tree_fat.obj") catch {
        @panic("failed loading statue");
    };

    // build the level mesh
    const level_start_x = -10;
    const level_start_z = -10;
    var level_start = Vec3{ .x = 0, .y = 0.5, .z = 0 };
    var pos = Vec3{ .x = 0, .y = 0, .z = 0 };
    var level_mesh_data = .{
        .verts = std.ArrayList(Vertex).init(alloc),
        .indices = std.ArrayList(u16).init(alloc),
    };
    const block_size: Vec3 = .{
        .x = Level.TILE_SCALE,
        .y = 2,
        .z = Level.TILE_SCALE,
    };

    level = Level.init(levelString);
    var l_it = level.iter();
    while (l_it.next()) |c| {
        switch (level.at(c)) {
            .WALL => {
                var offset = @intCast(u16, level_mesh_data.verts.items.len);
                var faces = cube.north_face_verts ++
                    cube.south_face_verts ++
                    cube.west_face_verts ++
                    cube.east_face_verts ++
                    // cube.bottom_face_verts ++
                    cube.top_face_verts;
                for (faces) |v| {
                    _ = level_mesh_data.verts.append(v.translate(.{ .x = @intToFloat(f32, c.x), .y = 0, .z = @intToFloat(f32, c.y) })) catch unreachable;
                }
                var i: u16 = 0;
                while (i < faces.len) : (i += 4) {
                    for (quad.indices) |index| {
                        _ = level_mesh_data.indices.append(index + offset + i) catch unreachable;
                    }
                }
            },
            else => {},
        }
    }

    map_pass = minimapPass();
    render_pass = renderPass();
    const level_mesh = sr.loadMesh(level_mesh_data.verts.items, level_mesh_data.indices.items);
    _ = sr.objs.add(.{
        .mesh = level_mesh,
        .transform = Mat4.createScale(block_size.x, block_size.y, block_size.z),
        .pos = level_start,
        // .texture = map_texture,
    });
}

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
var r: TextureRenderer = .{};
var textRenderer: text.Renderer = .{};

const white = 0xffffffff;

const target_frametime = 8.33;
var last_time: u64 = 0;

var last_move_time: u64 = 0;

fn drawMap() void {
    var xy = vec2(2, 2);
    var map_w: f32 = minimap_max_w - xy.x * 2;
    var map_h: f32 = minimap_max_h - xy.y * 2;
    r.drawRect(.{ .pos = xy, .w = map_w, .h = map_h }, .{
        .tint = 0xffabede2,
    });

    // map should be centered around the player:
    // - find center of texture

    var center = Vec2.new(map_w / 2, map_h / 2);

    var block_size: f32 = if (map_open) 2 else 8;
    var pad: f32 = if (map_open) 1 else 4;
    var l_it = level.iter();
    while (l_it.next()) |c| {
        var tint: u32 = 0xff0000ff;
        if (level.at(c).solid()) {
            tint = 0xff000000;
        } else if (coordsEqual(player.coord, c)) {
            tint = white;
        }
        r.drawRect(.{ .pos = center.add(Vec2.new(@intToFloat(f32, c.x - player.coord.x), @intToFloat(f32, c.y - player.coord.y)).scale(block_size + pad)), .w = block_size, .h = block_size }, .{ .tint = tint });
    }

    // borders

    // left
    r.drawRect(.{ .pos = .{ .x = xy.x - 2, .y = xy.y - 2 }, .w = 2, .h = map_h + 4 }, .{});
    // right
    r.drawRect(.{ .pos = .{ .x = xy.x + map_w, .y = xy.y - 2 }, .w = 2, .h = map_h + 4 }, .{});
    // top
    r.drawRect(.{ .pos = .{ .x = xy.x - 2, .y = xy.y - 2 }, .w = map_w + 4, .h = 2 }, .{});
    // bottom
    r.drawRect(.{ .pos = .{ .x = xy.x - 2, .y = xy.y + map_h }, .w = map_w + 4, .h = 2 }, .{});
}

const minimap_max_w = 512 / 4;
const minimap_max_h = 512 / 4;
var map_texture: sg.Image = .{};
var render_texture: sg.Image = .{};

fn renderPass() sg.Pass {
    var img_desc: sg.ImageDesc = .{
        .render_target = true,
        .width = 240,
        .height = 160,
        .pixel_format = .RGBA8,
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        // .min_filter = .LINEAR,
        // .mag_filter = .LINEAR,
        // .wrap_u = .REPEAT,
        // .wrap_v = .REPEAT,
        .sample_count = sample_count,
    };
    render_texture = sg.makeImage(img_desc);
    img_desc.pixel_format = .DEPTH;
    const depth_img = sg.makeImage(img_desc);

    var pass_desc: sg.PassDesc = .{};
    pass_desc.color_attachments[0].image = render_texture;
    pass_desc.depth_stencil_attachment.image = depth_img;
    return sg.makePass(pass_desc);
}

fn minimapPass() sg.Pass {
    var img_desc: sg.ImageDesc = .{
        .render_target = true,
        .width = minimap_max_w,
        .height = minimap_max_h,
        .pixel_format = .RGBA8,
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        // .wrap_u = .REPEAT,
        // .wrap_v = .REPEAT,
        .sample_count = sample_count,
    };
    map_texture = sg.makeImage(img_desc);
    img_desc.pixel_format = .DEPTH;
    const depth_img = sg.makeImage(img_desc);

    var pass_desc: sg.PassDesc = .{};
    pass_desc.color_attachments[0].image = map_texture;
    pass_desc.depth_stencil_attachment.image = depth_img;
    return sg.makePass(pass_desc);
}

export fn frame() void {
    const now = stime.now();
    const x = now - last_time;
    const dt = stime.ms(x);
    if (dt < target_frametime) {
        const ns = (target_frametime - stime.ms(x)) * 1_000_000;
        std.time.sleep(@floatToInt(u64, ns));
    }
    last_time = now;

    if (state.inputs.heldOnce(.M)) {
        map_open = !map_open;
    }
    const moveSpeed = @floatCast(f32, 0.01 * dt);
    if (stime.ms(now - last_move_time) > 200) {
        var new_pos = player.coord;
        if (state.inputs.held(.S)) {
            switch (player.facing) {
                .NORTH => new_pos.y -= 1,
                .EAST => new_pos.x += 1,
                .SOUTH => new_pos.y += 1,
                .WEST => new_pos.x -= 1,
            }
        }
        if (state.inputs.held(.W)) {
            switch (player.facing) {
                .NORTH => new_pos.y += 1,
                .EAST => new_pos.x -= 1,
                .SOUTH => new_pos.y -= 1,
                .WEST => new_pos.x += 1,
            }
        }
        if (state.inputs.held(.Q)) {
            switch (player.facing) {
                .NORTH => new_pos.x += 1,
                .EAST => new_pos.y += 1,
                .SOUTH => new_pos.x -= 1,
                .WEST => new_pos.y -= 1,
            }
        }
        if (state.inputs.held(.E)) {
            switch (player.facing) {
                .NORTH => new_pos.x -= 1,
                .EAST => new_pos.y -= 1,
                .SOUTH => new_pos.x += 1,
                .WEST => new_pos.y += 1,
            }
        }
        if (!coordsEqual(player.coord, new_pos) and !level.collide(new_pos)) {
            player.coord = new_pos;
            last_move_time = now;
        }
        if (state.inputs.held(.A)) {
            player.facing = switch (player.facing) {
                .EAST => .NORTH,
                .SOUTH => .EAST,
                .WEST => .SOUTH,
                .NORTH => .WEST,
            };
            last_move_time = now;
        }
        if (state.inputs.held(.D)) {
            player.facing = switch (player.facing) {
                .NORTH => .EAST,
                .EAST => .SOUTH,
                .SOUTH => .WEST,
                .WEST => .NORTH,
            };
            last_move_time = now;
        }
    }
    var target_pos = level.fromGridCoord(player.coord);
    target_pos.y = player.height;
    sr.camera.pos = sr.camera.pos.add(target_pos.sub(sr.camera.pos).scale(0.1));

    const turnSpeed = 0.05 * @floatCast(f32, dt / 10);
    var dir = sr.camera.dir;
    switch (player.facing) {
        .NORTH => dir = .{ .x = 0, .y = 0, .z = -1 },
        .EAST => dir = .{ .x = 1, .y = 0, .z = 0 },
        .SOUTH => dir = .{ .x = 0, .y = 0, .z = 1 },
        .WEST => dir = .{ .x = -1, .y = 0, .z = 0 },
    }
    sr.camera.dir = sr.camera.dir.add(dir.sub(sr.camera.dir).scale(0.1));

    {
        sg.beginPass(map_pass, state.opa);
        sg.applyPipeline(state.offscreen_pip);
        r.begin(Mat4.createOrthogonal(0, minimap_max_w, minimap_max_h, 0, -1, 1));
        drawMap();
        r.end();
        sg.endPass();
    }

    {
        sg.beginPass(render_pass, state.opa);

        // render scene
        //
        sr.render();

        sg.applyPipeline(state.offscreen_pip);
        // render UI (ortho)
        //
        // TODO(ktravis): this should work as just plain "world-space" text, need to adapt it
        const proj = Mat4.createPerspective(zlm.toRadians(60.0), sapp.widthf() / sapp.heightf(), 0.01, 100.0);
        const view_proj = Mat4.mul(proj, sr.camera.view());

        r.begin(Mat4.createOrthogonal(0, sapp.widthf() / 4, sapp.heightf() / 4, 0, -1, 1));

        {
            if (map_open) {
                r.drawRectTextured(.{ .pos = .{ .x = (sapp.widthf() / 4) / 2 - 250 / 4, .y = 10 / 4 }, .w = minimap_max_w, .h = minimap_max_h }, .{}, map_texture);
            } else {
                r.drawRectTextured(.{ .pos = .{ .x = sapp.widthf() / 4 - 60, .y = 2 }, .w = minimap_max_w / 2, .h = minimap_max_h / 2 }, .{ .tint = 0xaaffffff }, map_texture);
            }
        }

        r.end();
        sg.endPass();
    }

    {
        sg.beginDefaultPass(state.pass_action, sapp.width(), sapp.height());
        sg.applyPipeline(state.pip);
        r.begin(Mat4.createOrthogonal(0, sapp.widthf(), sapp.heightf(), 0, -1, 1));
        r.drawRectTextured(.{ .pos = .{ .x = 0, .y = 0 }, .w = sapp.widthf(), .h = sapp.heightf() }, .{}, render_texture);
        var buf: [256]u8 = undefined;
        textRenderer.drawString(&r, std.fmt.bufPrint(&buf, "pos: [{}, {}]", .{ player.coord.x, player.coord.y }) catch "error", .{ .x = 8, .y = 28 }, .{ .scale = 0.5 });
        r.end();
        sg.endPass();
    }

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
        .width = 240 * 4,
        .height = 160 * 4,
        .sample_count = sample_count,
        .window_title = "potion cellar",
    });
}
