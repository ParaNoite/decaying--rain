shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.36, 0.38, 0.36, 1.0);
uniform vec4 stain_color : source_color = vec4(0.065, 0.075, 0.063, 1.0);
uniform float metal = 0.0;
uniform float floor_surface = 0.0;
uniform float scale_noise = 1.0;
uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.yzx + 33.33); return fract((p.x+p.y)*p.z); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) { return noise3(p)*0.52+noise3(p*2.07)*0.27+noise3(p*4.13)*0.14+noise3(p*8.29)*0.07; }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
 vec3 p=world_pos*scale_noise;
 float broad=fbm(p*0.65);
 float grain=noise3(p*42.0);
 float streak=fbm(p*vec3(3.8,0.13,3.8));
 float stain=smoothstep(0.46,0.70,streak)*0.64;
 float flake=smoothstep(0.43,0.64,fbm(p*4.5));
 vec3 col=mix(base_color.rgb,stain_color.rgb,stain);
 col*=mix(0.5,1.35,broad)*mix(0.80,1.12,grain);
 col=mix(col,base_color.rgb*1.38,flake*0.24);
 vec3 blend=pow(abs(world_normal),vec3(8.0)); blend/=max(dot(blend,vec3(1.0)),0.001);
 vec3 scan=texture(concrete_scan,p.zy*0.23).rgb*blend.x+texture(concrete_scan,p.xz*0.23).rgb*blend.y+texture(concrete_scan,p.xy*0.23).rgb*blend.z;
 if(metal<0.1) { col=mix(col,scan*1.6,0.85)*(1.0-stain*0.62); }
 if(metal>0.1) { float rust=smoothstep(0.43,0.67,fbm(p*3.2)); col=mix(col,vec3(0.12,0.073,0.035),rust*0.6); col*=mix(0.6,1.55,clamp(dot(scan,vec3(0.333))*5.0,0.0,1.0)); }
 float wet=0.0;
 if(floor_surface>0.5) {
   wet=smoothstep(0.45,0.53,fbm(p*vec3(0.65,1,0.65)));
   vec2 cell=abs(fract(p.xz/3.4)-0.5);
   float seam=smoothstep(0.491,0.499,max(cell.x,cell.y));
   col*=1.0-seam*0.58;
   col=mix(col,vec3(0.035,0.045,0.043),wet*0.62);
 }
 ALBEDO=col;
 METALLIC=mix(metal*(1.0-stain*0.65),0.32,wet);
 ROUGHNESS=mix(mix(0.9,0.61,metal),0.09,wet);
 SPECULAR=0.5;
 float relief=mix(grain,dot(scan,vec3(0.333)),float(metal<0.1));
 vec3 bump=vec3(dFdx(relief),dFdy(relief),0.0);
 NORMAL=normalize(NORMAL-bump*mix(0.8,0.018,wet));
}
