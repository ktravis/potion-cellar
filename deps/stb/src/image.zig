pub const Image = struct {
    w: u32,
    h: u32,
    channels: u32,
    data: []u8,
};

extern fn stbi_load_from_memory([*]const u8, c_int, *c_int, *c_int, *c_int, c_int) [*]u8;
extern fn stbi_set_flip_vertically_on_load(c_int) void;

pub fn setFlipVerticallyOnLoad(flip: bool) void {
    stbi_set_flip_vertically_on_load(if (flip) 1 else 0);
}

pub fn loadFromMemory(buf: []const u8, channels: usize) Image {
    var img: Image = undefined;
    img.data = stbi_load_from_memory(buf.ptr, @intCast(c_int, buf.len), @ptrCast(*c_int, &img.w), @ptrCast(*c_int, &img.h), @ptrCast(*c_int, &img.channels), @intCast(c_int, channels))[0 .. img.w * img.h * img.channels];
    return img;
}
