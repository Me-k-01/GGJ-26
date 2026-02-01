shader_type spatial;
 
uniform float spin_speed : hint_range(0, 10) = 1.0; // Speed of spinning
uniform float bounce_amplitude : hint_range(0, 1) = 0.5; // Amplitude of bounce
uniform float bounce_frequency : hint_range(0, 10) = 1.0; // Frequency of bounce

uniform sampler2D asset_texture;

uniform vec3 color_mask : source_color = vec3(1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.679, 0.23, 1.0); // Color of the glow
uniform float alpha : hint_range(0, 1) = 1.0; // Color of the glow
//uniform float threshold;
//uniform float intensity;
//uniform float opacity;
//uniform vec4 glow_color : source_color;

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}
vec3 fresnel_glow(float amount, float intensity, vec3 color, vec3 normal, vec3 view)
{
	return pow((1.0 - dot(normalize(normal), normalize(view))), amount) * color * intensity;
}
 
 
void vertex() {   
}
void fragment() { 
	vec4 tex = texture(asset_texture, UV);
	ALBEDO = tex.rgb * color_mask;
	float fresnel_val = fresnel(3.0, NORMAL, VIEW);
	ALPHA = fresnel_val * (1.0-alpha) + alpha * tex.a;
	EMISSION = fresnel_val * glow_color.rgb *10.0;
}
	
