shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size;
uniform vec2 screen_to_world_x;
uniform vec2 screen_to_world_y;
uniform vec2 world_origin;
uniform vec2 player_position;
uniform float sight_radius = 160.0;

void fragment() {
	vec2 screen_position = UV * viewport_size;
	vec2 world_position = world_origin + screen_to_world_x * screen_position.x + screen_to_world_y * screen_position.y;
	float outside = step(sight_radius, distance(world_position, player_position));
	COLOR = vec4(0.0, 0.0, 0.0, outside);
}
