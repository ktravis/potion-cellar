const sokol = @import("sokol");
const sg = sokol.gfx;
const math = @import("../math.zig");

// a uniform block struct with a model-view-projection matrix
pub const VsParams = packed struct {
    mvp: math.Mat4 = math.Mat4.identity(),
    draw_mode: f32 = 0.0,
    pad: [12]u8 = undefined,
};


// build a backend-specific ShaderDesc struct
pub fn desc() sg.ShaderDesc {
    var result: sg.ShaderDesc = .{};
    result.vs.uniform_blocks[0].size = @sizeOf(VsParams);
    switch (sg.queryBackend()) {
        // shader code is copied output from sokol-shdc!
        .METAL_MACOS => {
            result.vs.source =
                \\ #include <metal_stdlib>
                \\ using namespace metal;
                \\ struct vs_params {
                \\     float4x4 mvp;
                \\     float draw_mode;
                \\ };
                \\ struct vs_in {
                \\     float4 position [[attribute(0)]];
                \\     float3 normal [[attribute(1)]];
                \\     float2 texcoord [[attribute(2)]];
                \\     float4 color0 [[attribute(3)]];
                \\ };
                \\ struct vs_out {
                \\     float4 color [[user(locn0)]];
                \\     float4 position [[position]];
                \\ };
                \\ vertex vs_out _main(vs_in in [[stage_in]], constant vs_params& params [[buffer(0)]]) {
                \\     vs_out out = {};
                \\     out.position = params.mvp * in.position;
                \\     if (params.draw_mode == 0.0) {
                \\         out.color = float4((in.normal + float3(1.0)) * 0.5, 1.0);
                \\     }
                \\     else if (params.draw_mode == 1.0) {
                \\         out.color = float4(in.texcoord, 0.0, 1.0);
                \\     }
                \\     else {
                \\         out.color = in.color0;
                \\     }
                \\     return out;
                \\ }
            ;
            result.fs.source =
                \\ #include <metal_stdlib>
                \\ using namespace metal;
                \\ struct fs_out {
                \\     float4 frag_color [[color(0)]];
                \\ };
                \\ struct fs_in {
                \\     float4 color [[user(locn0)]];
                \\ };
                \\ fragment fs_out _main(fs_in in [[stage_in]]) {
                \\     fs_out out = {};
                \\     out.frag_color = in.color;
                \\     return out;
                \\ }
            ;
        },
        .GLCORE33 => {
            result.vs.uniform_blocks[0].uniforms[0].name = "vs_params";
            result.vs.uniform_blocks[0].uniforms[0].type = .FLOAT4;
            result.vs.uniform_blocks[0].uniforms[0].array_count = 5;
            result.vs.source =
                \\ #version 330
                \\ uniform vec4 vs_params[5];
                \\ layout(location = 0) in vec4 position;
                \\ out vec4 color;
                \\ layout(location = 1) in vec3 normal;
                \\ layout(location = 2) in vec2 texcoord;
                \\ layout(location = 3) in vec4 color0;
                \\ void main() {
                \\     gl_Position = mat4(vs_params[0], vs_params[1], vs_params[2], vs_params[3]) * position;
                \\     if (vs_params[4].x == 0.0) {
                \\         color = vec4((normal + vec3(1.0)) * 0.5, 1.0);
                \\     }
                \\     else {
                \\         if (vs_params[4].x == 1.0) {
                \\             color = vec4(texcoord, 0.0, 1.0);
                \\         }
                \\         else {
                \\             color = color0;
                \\         }
                \\     }
                \\ }
            ;
            result.fs.source =
                \\ #version 330
                \\ layout(location = 0) out vec4 frag_color;
                \\ in vec4 color;
                \\ void main() {
                \\     frag_color = color;
                \\ }
            ;
        },
        .D3D11 => {
            result.attrs[0] = .{ .sem_name = "POSITION" };
            result.attrs[1] = .{ .sem_name = "NORMAL" };
            result.attrs[2] = .{ .sem_name = "TEXCOORD" };
            result.attrs[3] = .{ .sem_name = "COLOR" };
            result.vs.source =
                \\ cbuffer params: register(b0) {
                \\   float4x4 mvp;
                \\   float draw_mode;
                \\ };
                \\ struct vs_in {
                \\   float4 pos: POSITION;
                \\   float3 normal: NORMAL;
                \\   float2 texcoord: TEXCOORD;
                \\   float4 color: COLOR;
                \\ };
                \\ struct vs_out {
                \\   float4 color: COLOR0;
                \\   float4 pos: SV_Position;
                \\ };
                \\ vs_out main(vs_in inp) {
                \\   vs_out outp;
                \\   outp.pos = mul(mvp, inp.pos);
                \\   if (draw_mode == 0.0) {
                \\     outp.color = float4((inp.normal + 1.0) * 0.5, 1.0);
                \\   }
                \\   else if (draw_mode == 1.0) {
                \\     outp.color = float4(inp.texcoord, 0.0, 1.0);
                \\   }
                \\   else {
                \\     outp.color = inp.color;
                \\   }
                \\   return outp;
                \\ }
            ;
            result.fs.source =
                \\ float4 main(float4 color: COLOR0): SV_Target0 {
                \\   return color;
                \\ }
            ;
        },
        else => {},
    }
    return result;
}
