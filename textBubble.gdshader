shader_type canvas_item;

// Controles para tu AnimationPlayer
uniform float tamano_bulto : hint_range(0.0, 0.4) = 0.2; // Cuánto se estrecha la burbuja
uniform float posicion_x : hint_range(0.0, 1.0) = 0.5;
uniform float ancho_bulto : hint_range(0.1, 1.0) = 0.3; // Controla lo ancho/circular que es el bulto

void fragment() {
    // COLOR ya contiene el color verde o gris que le diste por código a tu StyleBox
    vec4 color_fondo = COLOR;
    
    // 1. Distancia desde el centro de la bola
    float distancia = abs(UV.x - posicion_x);
    
    // 2. smoothstep crea una curva circular perfecta (forma de campana orgánica)
    float curva = smoothstep(ancho_bulto, 0.0, distancia);
    
    // 3. Truco visual: En lugar de intentar dibujar fuera del contenedor (lo cual cortaría la imagen),
    // encogemos el tubo en las partes donde NO está la bola.
    float compresion = (1.0 - curva) * tamano_bulto;
    
    // 4. Si el píxel está dentro de la nueva forma curva, lo pintamos. Si no, transparente.
    if (UV.y > compresion && UV.y < (1.0 - compresion)) {
        COLOR = color_fondo;
    } else {
        COLOR = vec4(0.0);
    }
}