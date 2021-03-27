const std = @import("std");
const sokol = @import("sokol");
const zlm = @import("zlm");
const stbi = @import("stb").image;

const sg = sokol.gfx;
const vec2 = zlm.vec2;
const Vec2 = zlm.Vec2;
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;

usingnamespace @import("geom.zig");
usingnamespace @import("renderer.zig");

pub const Sprite = struct {
    texture: sg.Image,
    width: u32,
    height: u32,
    uv_rect: UVRect,
    sheet: ?*const SpriteSheet,
    tint: u32 = 0xFF_FF_FF_FF,
};

pub const SpriteSheet = struct {
    width: u32,
    height: u32,
    sprite_width: u32,
    sprite_height: u32,
    texture: sg.Image,

    pub fn fromImage(img: stbi.Image, sprite_w: u32, sprite_h: u32) SpriteSheet {
        var img_desc: sg.ImageDesc = .{
            .width = @intCast(i32, img.w),
            .height = @intCast(i32, img.h),
            .min_filter = .NEAREST,
            .mag_filter = .NEAREST,
            .wrap_u = .CLAMP_TO_EDGE,
            .wrap_v = .CLAMP_TO_EDGE,
            .sample_count = 1,
        };
        img_desc.data.subimage[0][0] = sg.asRange(img.data);
        var t = sg.makeImage(img_desc);

        return .{
            .width = img.w,
            .height = img.h,
            .sprite_width = sprite_w,
            .sprite_height = sprite_h,
            .texture = t,
        };
    }

    pub fn index(self: *const SpriteSheet, i: usize) Sprite {
        const cols = (self.width / self.sprite_width);
        const rows = (self.height / self.sprite_height);
        std.debug.assert(i < cols * rows);
        const x = i % cols;
        const y = i / rows;
        return .{
            .texture = self.texture,
            .width = self.sprite_width,
            .height = self.sprite_height,
            .uv_rect = .{
                .a = vec2(@intToFloat(f32, x) / @intToFloat(f32, cols), 1 - @intToFloat(f32, y + 1) / @intToFloat(f32, rows)),
                .b = vec2(@intToFloat(f32, x + 1) / @intToFloat(f32, cols), 1 - @intToFloat(f32, y) / @intToFloat(f32, rows)),
            },
            .sheet = self,
        };
    }
};
