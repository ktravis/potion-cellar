const sokol = @import("sokol");
const sg = sokol.gfx;
// const math = @import("../math.zig");
const zlm = @import("zlm");
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;

// a uniform block struct with a model-view-projection matrix
pub const VsParams = packed struct { mvp: Mat4 };

// build a backend-specific ShaderDesc struct
pub fn desc() sg.ShaderDesc {
    var result: sg.ShaderDesc = .{};
    result.vs.uniform_blocks[0].size = @sizeOf(VsParams);
    result.fs.images[0].image_type = ._2D;
    switch (sg.queryBackend()) {
        .D3D11 => {
            result.attrs[0].sem_name = "POSITION";
            result.attrs[1].sem_name = "COLOR";
            result.attrs[2].sem_name = "TEXCOORD";
            result.vs.source =
                \\ cbuffer params: register(b0) {
                \\   float4x4 mvp;
                \\ };
                \\ struct vs_in {
                \\   float4 pos: POSITION;
                \\   float4 color: COLOR;
                \\   float2 uv: TEXCOORD;
                \\ };
                \\ struct vs_out {
                \\   float4 color: COLOR0;
                \\   float2 uv: TEXCOORD0;
                \\   float4 pos: SV_Position;
                \\ };
                \\ vs_out main(vs_in inp) {
                \\   vs_out outp;
                \\   outp.pos = mul(mvp, inp.pos);
                \\   outp.color = inp.color;
                \\   outp.uv = inp.uv;
                \\   return outp;
                \\ }
            ;
            result.fs.source =
                \\Texture2D<float4> tex: register(t0);
                \\sampler smp: register(s0);
                \\float4 main(float4 color: COLOR0, float2 uv: TEXCOORD0): SV_Target0 {
                \\  return tex.Sample(smp, uv) * color;
                \\}
            ;
        },
        .GLCORE33 => {
            result.vs.uniform_blocks[0].uniforms[0] = .{ .name = "mvp", .type = .MAT4 };
            result.fs.images[0].name = "tex";
            result.vs.source =
                \\ #version 330
                \\ uniform mat4 mvp;
                \\ layout(location = 0) in vec4 position;
                \\ layout(location = 1) in vec4 color0;
                \\ layout(location = 2) in vec2 texcoord0;
                \\ out vec4 color;
                \\ out vec2 uv;
                \\ void main() {
                \\   gl_Position = mvp * position;
                \\   color = color0;
                \\   uv = texcoord0;
                \\ }
            ;
            result.fs.source =
                \\ #version 330
                \\ uniform sampler2D tex;
                \\ in vec4 color;
                \\ in vec2 uv;
                \\ out vec4 frag_color;
                \\ void main() {
                \\   vec4 texel = texture(tex, uv);
                \\   frag_color = texel * color;
                \\ }
            ;
        },
        else => {},
    }
    return result;
}
