shader_type spatial;

uniform vec4 aura_color = vec4(1.0, 0.8, 0.0, 1.0); // couleur de l'aura
uniform float aura_thickness = 0.05;                 // épaisseur de l'aura

void vertex() {
    VERTEX += NORMAL * aura_thickness;
}

void fragment() {
    ALBEDO = aura_color.rgb;
    ALPHA = aura_color.a;
}
