const sokol = @import("sokol");
const sg = sokol.gfx;
const math = @import("../math.zig");

// a uniform block struct with a model-view-projection matrix
pub const VsParams = extern struct {
    model: math.Mat4,
    view: math.Mat4,
    projection: math.Mat4,
    view_pos: math.Vec3,
    // light_pos: math.Vec3,
    // pad: f32 = 0.0,
    // pad: [4]u8 = undefined,
};

// pub const FsParams = packed struct {
//     light_pos: math.Vec3,
// };

// build a backend-specific ShaderDesc struct
pub fn desc() sg.ShaderDesc {
    var result: sg.ShaderDesc = .{};
    result.vs.uniform_blocks[0].size = @sizeOf(VsParams);
    // result.fs.uniform_blocks[0].size = @sizeOf(FsParams);
    result.fs.images[0].type = ._2D;
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
            result.vs.uniform_blocks[0].uniforms[0] = .{ .name = "model", .type = .MAT4 };
            result.vs.uniform_blocks[0].uniforms[1] = .{ .name = "view", .type = .MAT4 };
            result.vs.uniform_blocks[0].uniforms[2] = .{ .name = "projection", .type = .MAT4 };
            result.vs.uniform_blocks[0].uniforms[3] = .{ .name = "view_pos", .type = .FLOAT3 };
            // result.vs.uniform_blocks[0].uniforms[3] = .{ .name = "light_pos", .type = .FLOAT3 };
            result.fs.images[0].name = "tex";
            result.vs.source =
                \\ #version 330
                \\ uniform mat4 model;
                \\ uniform mat4 view;
                \\ uniform mat4 projection;
                \\ uniform vec3 view_pos;
                \\ layout(location = 0) in vec3 position;
                \\ layout(location = 1) in vec4 color0;
                \\ layout(location = 2) in vec2 texcoord0;
                \\ layout(location = 3) in vec3 normal;
                \\ out vec4 color;
                \\ out vec2 uv;
                \\ out vec3 Normal;
                \\ out vec3 frag_pos;
                \\ out vec3 lightPos;
                \\ out vec3 viewPos;
                \\ void main() {
                \\   gl_Position = projection * view * model * vec4(position, 1.0);
                \\   color = color0;
                \\   uv = texcoord0;
                \\   Normal = mat3(transpose(inverse(model))) * normal;
                \\   frag_pos = vec3(model * vec4(position, 1.0));
                \\   lightPos = vec3(0, 10, 5);
                \\   viewPos = view_pos;
                \\ }
            ;
            result.fs.source =
                \\ #version 330
                \\ uniform sampler2D tex;
                \\ in vec4 color;
                \\ in vec2 uv;
                \\ in vec3 Normal;
                \\ in vec3 frag_pos;
                \\ in vec3 lightPos;
                \\ in vec3 viewPos;
                \\ out vec4 frag_color;
                \\ void main() {
                \\   vec4 texel = texture(tex, uv);
                \\   if (texel.a < 0.1) {
                \\     discard;
                \\   }
                \\   vec3 lightColor = vec3(1, 1, 1);
                \\   float ambientStrength = 0.2;
                \\   float specularStrength = 0.5;
                \\   vec3 ambient = ambientStrength * lightColor;
                \\   vec3 norm = normalize(Normal);
                \\   vec3 light_dir = normalize(lightPos - frag_pos);
                \\   float diff = clamp(dot(norm, light_dir), 0.0, 1.0);
                \\   vec3 viewDir = normalize(viewPos - frag_pos);
                \\   vec3 reflectDir = reflect(-light_dir, norm);
                \\   float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
                \\   vec3 specular = specularStrength * spec * lightColor;
                \\   vec3 diffuse = diff * lightColor;
                \\   vec4 lit_color = vec4(ambient + diffuse + specular, 1.0) * color;
                \\   frag_color = texel * lit_color;
                \\ }
            ;
        },
        else => {},
    }
    return result;
}
