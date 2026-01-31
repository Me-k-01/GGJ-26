shader_type spatial;
render_mode diffuse_lambert;

//
// Utility noise functions (3D FBM)
//

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash(i + vec3(0,0,0));
	float n100 = hash(i + vec3(1,0,0));
	float n010 = hash(i + vec3(0,1,0));
	float n110 = hash(i + vec3(1,1,0));
	float n001 = hash(i + vec3(0,0,1));
	float n101 = hash(i + vec3(1,0,1));
	float n011 = hash(i + vec3(0,1,1));
	float n111 = hash(i + vec3(1,1,1));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);

	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);

	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < 4; i++) {
		value += noise(p * frequency) * amplitude;
		frequency *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}
//varying vec2 vert;
//
//void vertex(){
	//vert = VERTEX;
//}
void fragment() {
	// Equivalent of Geometry → Position
	vec3 pos = VERTEX;
	//vec3 pos = WORLD_POSITION;

	// Mapping node (Texture space)
	// Blender: Rotation Y = 90°, Z offset ≈ 6.6
	pos = vec3(pos.z, pos.y, -pos.x);
	pos.z += 6.6;

	// Noise Texture settings
	float scale = 5.3;
	float n = fbm(pos * scale);

	// Gradient Texture (vertical easing gradient)
	float gradient = clamp(pos.y * 0.5 + 0.5, 0.0, 1.0);

	// Add node + Clamp
	float result = clamp(n + gradient, 0.0, 1.0);

	// Diffuse BSDF → Albedo
	ALBEDO = vec3(1);
	ROUGHNESS = 0.66;
}
