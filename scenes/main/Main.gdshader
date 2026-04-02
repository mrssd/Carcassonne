shader_type canvas_item;

// Adjust 'roundness' in the Inspector under Shader Parameters
uniform float roundness : hint_range(0.0, 0.5) = 0.1;

void fragment() {
    vec2 center_uv = UV - 0.5;
    vec2 q = abs(center_uv) - 0.5 + roundness;
    float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - roundness;
    
    vec4 tex = texture(TEXTURE, UV);
    // This creates the smooth rounded alpha mask
    COLOR = vec4(tex.rgb, tex.a * (1.0 - smoothstep(0.0, 0.01, dist)));
}