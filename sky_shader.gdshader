shader_type canvas_item;

uniform float pixel_size = 32.0;
uniform vec4 top_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);

void fragment() {
    // Pixelate UV coordinates
    vec2 pixelated_uv = floor(UV * pixel_size) / pixel_size;
    
    // Create gradient from top to bottom
    COLOR = mix(bottom_color, top_color, pixelated_uv.y);
}