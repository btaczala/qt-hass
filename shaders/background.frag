#version 440

// AnimatedBackground's gradient: four colors along a diagonal band `span`
// window diagonals long, of which the window shows the part `drift` (0..1) of
// the way along. Dithered before output, so the few 8-bit shades between
// neighboring colors don't show up as flat stripes.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color0;
    vec4 color1;
    vec4 color2;
    vec4 color3;
    vec2 resolution;
    float span;
    float drift;
};

// Hash without sine (Dave Hoskins), stable across GPUs.
float hash(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main()
{
    vec2 pixel = qt_TexCoord0 * resolution;
    float diagonal = length(resolution);
    // Distance along the top-left to bottom-right diagonal, from -0.5 to 0.5
    // window diagonals.
    float along = dot(pixel - 0.5 * resolution, vec2(0.70710678)) / diagonal;
    float t = clamp((along + 0.5 + drift * (span - 1.0)) / span, 0.0, 1.0);

    float segment = t * 3.0;
    vec4 color = segment < 1.0 ? mix(color0, color1, segment)
               : segment < 2.0 ? mix(color1, color2, segment - 1.0)
                               : mix(color2, color3, segment - 2.0);

    // Triangular noise of +-1 shade, added before the 8-bit quantization.
    float noise = hash(gl_FragCoord.xy) + hash(gl_FragCoord.xy + vec2(17.0, 59.0)) - 1.0;
    fragColor = vec4(color.rgb + noise / 255.0, 1.0) * qt_Opacity;
}
