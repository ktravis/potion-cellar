const sokol = @import("sokol");
const sg = sokol.gfx;
// const math = @import("../math.zig");
const zlm = @import("zlm");
const vec3 = zlm.vec3;
const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4;

pub const PointLight = extern struct {
    pos: Vec3,
};

// a uniform block struct with a model-view-projection matrix
pub const VsParams = extern struct {
    model: Mat4,
    view: Mat4,
    projection: Mat4,
    view_pos: Vec3,
    num_lights: f32 = 0.0,
    lights: [8]PointLight = undefined,
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
            result.vs.uniform_blocks[0].uniforms[0] = .{ .name = "model", .type = .MAT4 };
            result.vs.uniform_blocks[0].uniforms[1] = .{ .name = "view", .type = .MAT4 };
            result.vs.uniform_blocks[0].uniforms[2] = .{ .name = "projection", .type = .MAT4 };
            result.vs.uniform_blocks[0].uniforms[3] = .{ .name = "view_pos", .type = .FLOAT3 };
            result.vs.uniform_blocks[0].uniforms[4] = .{ .name = "num_lights", .type = .FLOAT };
            result.vs.uniform_blocks[0].uniforms[5] = .{ .name = "lights", .type = .FLOAT3, .array_count = 8 };
            // result.vs.uniform_blocks[0].uniforms[3] = .{ .name = "light_pos", .type = .FLOAT3 };
            result.fs.images[0].name = "tex";
            result.vs.source =
                \\ #version 330
                \\ uniform mat4 model;
                \\ uniform mat4 view;
                \\ uniform mat4 projection;
                \\ uniform vec3 view_pos;
                \\ uniform float num_lights;
                \\ uniform vec3 lights[8];
                \\ layout(location = 0) in vec3 position;
                \\ layout(location = 1) in vec4 color0;
                \\ layout(location = 2) in vec2 texcoord0;
                \\ layout(location = 3) in vec3 normal;
                \\ out vec4 color;
                \\ out vec2 uv;
                \\ out vec3 Normal;
                \\ out vec3 frag_pos;
                \\ out vec3 viewPos;
                \\ flat out float numLights;
                \\ out vec3 the_lights[8];
                \\ void main() {
                \\   gl_Position = projection * view * model * vec4(position, 1.0);
                \\   color = color0;
                \\   uv = texcoord0;
                \\   Normal = mat3(transpose(inverse(model))) * normal;
                \\   frag_pos = vec3(model * vec4(position, 1.0));
                \\   numLights = num_lights;
                \\   the_lights = lights;
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
                \\ flat in float numLights;
                \\ in vec3 the_lights[8];
                \\ in vec3 viewPos;
                \\ out vec4 frag_color;
                \\ void main() {
                \\   vec4 texel = texture(tex, uv);
                \\   if (texel.a < 0.1) {
                \\     discard;
                \\   }
                \\   vec3 viewDir = normalize(viewPos - frag_pos);
                \\   float ambientStrength = 0.1;
                \\   float diffuseStrength = 0.5;
                // \\   float specularStrength = 0.1;
                \\   vec3 norm = normalize(Normal);
                \\   vec3 lit = vec3(0, 0, 0);
                \\   vec3 ambient = vec3(0, 0, 0);
                \\   vec3 diffuse = vec3(0, 0, 0);
                \\   for (int i = 0; i < numLights; i++) {
                \\     vec3 pos = the_lights[i];
                \\     vec3 lightColor = vec3(1, 1, 1);
                \\     vec3 light_dir = normalize(pos - frag_pos);
                \\     float l = length(pos - frag_pos);
                \\     float diff = clamp(dot(norm, light_dir) / (0.1 * l * l), 0.0, 1.0);
                // \\     vec3 reflectDir = reflect(-light_dir, norm);
                // \\     float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
                \\     ambient += ambientStrength * lightColor;
                \\     diffuse += diffuseStrength * diff * lightColor;
                // \\     vec3 specular = specularStrength * spec * lightColor;
                // \\     lit += ambient + diffuse + specular;
                \\   }
                \\   lit = ambient + diffuse;
                \\   frag_color = texel * vec4(lit, 1.0) * color;
                // \\   frag_color = texel * color *lit;
                \\ }
            ;
        },
        else => {},
    }
    return result;
}
