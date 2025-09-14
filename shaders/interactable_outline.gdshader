shader_type spatial;

uniform vec4 aura_color = vec4(0.039, 0.076, 0.076, 0.9); // couleur de l'aura
uniform float aura_thickness = 0.0;                 // épaisseur de l'aura

void vertex() {
    VERTEX += NORMAL * aura_thickness;
}

void fragment() {
    ALBEDO = aura_color.rgb;
    ALPHA = aura_color.a;
}

