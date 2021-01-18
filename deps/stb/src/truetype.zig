const std = @import("std");

pub const FontError = error{InitFailed};

pub const Font = struct {
    const Self = @This();
    const ATLAS_CHAR_COUNT = 96;
    pub const WIDTH = 512;
    pub const HEIGHT = 512;

    info: stbtt_fontinfo = undefined,
    tex: [WIDTH * HEIGHT]u32 = undefined,
    cdata: [ATLAS_CHAR_COUNT]stbtt_bakedchar = undefined,
    line_height: f32 = 0,

    pub fn init(data: [*c]const u8, size: f32) FontError!Self {
        var self = Self{};
        var result = stbtt_InitFont(&self.info, data, 0);
        if (result == 0) return FontError.InitFailed;
        var tmp: [WIDTH * HEIGHT]u8 = undefined;
        result = stbtt_BakeFontBitmap(data, 0, size, &tmp, WIDTH, HEIGHT, ' ', ATLAS_CHAR_COUNT, &self.cdata);
        if (result <= 0) return FontError.InitFailed;
        for (tmp) |a, i| {
            self.tex[i] = @intCast(u32, a) << 24 | 0xffffff;
        }

        var s = stbtt_ScaleForPixelHeight(&self.info, size);
        var asc: c_int = 0;
        var desc: c_int = 0;
        var gap: c_int = 0;
        stbtt_GetFontVMetrics(&self.info, &asc, &desc, &gap);
        self.line_height = s * @intToFloat(f32, asc - desc + gap);
        return self;
    }

    pub const Quad = struct {
        x0: f32 = 0,
        y0: f32 = 0,
        s0: f32 = 0,
        t0: f32 = 0,
        x1: f32 = 0,
        y1: f32 = 0,
        s1: f32 = 0,
        t1: f32 = 0,
        x_advance: f32 = 0,
        y_advance: f32 = 0,
    };

    pub fn getBakedQuad(self: *const Self, c: u8) Quad {
        var q: stbtt_aligned_quad = undefined;
        var x_advance: f32 = 0;
        var y_advance: f32 = 0;
        stbtt_GetBakedQuad(&self.cdata, WIDTH, HEIGHT, c - ' ', &x_advance, &y_advance, &q, 1); // TODO
        return .{
            .x0 = q.x0,
            .y0 = q.y0,
            .s0 = q.s0,
            .t0 = q.t0,
            .x1 = q.x1,
            .y1 = q.y1,
            .s1 = q.s1,
            .t1 = q.t1,
            .x_advance = x_advance,
            .y_advance = y_advance,
        };
    }
};

extern fn stbtt_InitFont(*stbtt_fontinfo, [*]const u8, c_int) c_int;
extern fn stbtt_ScaleForPixelHeight(*stbtt_fontinfo, f32) f32;
extern fn stbtt_GetFontVMetrics(*stbtt_fontinfo, *c_int, *c_int, *c_int) void;
extern fn stbtt_BakeFontBitmap([*]const u8, c_int, f32, [*]u8, c_int, c_int, c_int, c_int, [*]stbtt_bakedchar) c_int;
extern fn stbtt_GetBakedQuad([*]const stbtt_bakedchar, c_int, c_int, c_int, *f32, *f32, *stbtt_aligned_quad, c_int) void;

const stbtt_aligned_quad = extern struct {
    x0: f32,
    y0: f32,
    s0: f32,
    t0: f32,
    x1: f32,
    y1: f32,
    s1: f32,
    t1: f32,
};

const stbtt_bakedchar = extern struct {
    x0: c_ushort,
    y0: c_ushort,
    x1: c_ushort,
    y1: c_ushort,
    xoff: f32,
    yoff: f32,
    xadvance: f32,
};

const stbtt_buf = extern struct {
    data: [*c]u8,
    cursor: c_int,
    size: c_int,
};

const stbtt_fontinfo = extern struct {
    userdata: *c_void,
    data: [*c]u8,
    fontstart: c_int,
    numGlyps: c_int,

    loca: c_int,
    head: c_int,
    glyf: c_int,
    hhea: c_int,
    hmtx: c_int,
    kern: c_int,
    gpos: c_int,
    index_map: c_int,
    indexToLocFormat: c_int,

    cff: stbtt_buf,
    charstrings: stbtt_buf,
    gsubrs: stbtt_buf,
    subrs: stbtt_buf,
    fontdicts: stbtt_buf,
    fdselect: stbtt_buf,
};
