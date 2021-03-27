const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const tt = @import("stb").truetype;
// usingnamespace @import("math.zig");
const zlm = @import("zlm");
const vec2 = zlm.vec2;
const Vec2 = zlm.Vec2;
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;

const Buffer = @import("buffer.zig").Buffer;
usingnamespace @import("geom.zig");
usingnamespace @import("renderer.zig");

pub const Renderer = struct {
    const Self = @This();
    tr: TextureRenderer = .{},
    font: *tt.Font = undefined,
    font_texture: sg.Image = .{},

    pub fn init(self: *Self, f: *tt.Font) void {
        self.tr.init();
        var img_desc: sg.ImageDesc = .{
            .width = tt.Font.WIDTH,
            .height = tt.Font.HEIGHT,
            .pixel_format = .RGBA8,
        };
        img_desc.data.subimage[0][0] = sg.asRange(f.tex);
        self.font_texture = sg.makeImage(img_desc);
        self.font = f;
    }

    pub fn drawString(self: *Self, tr: *TextureRenderer, s: []const u8, pos: Vec2, opts: DrawOptions) void {
        var offset = Vec2.new(0, 0);
        for (s) |c, i| {
            if (c == '\n') {
                offset.x = 0;
                offset.y += self.font.line_height * opts.scale;
                continue;
            }
            var q = self.font.getBakedQuad(c);
            if (c != ' ' and c != '\t') {
                var r = Rect{
                    .pos = pos.add(vec2(offset.x + q.x0 * opts.scale, offset.y + q.y0 * opts.scale)),
                    .w = (q.x1 - q.x0),
                    .h = (q.y1 - q.y0),
                };
                var uv = UVRect{
                    .a = .{ .x = q.s0, .y = q.t1 },
                    .b = .{ .x = q.s1, .y = q.t0 },
                };
                tr.drawRectTexturedWithUV(r, uv, opts, self.font_texture);
            }
            offset.x += q.x_advance * opts.scale;
        }
    }
};
