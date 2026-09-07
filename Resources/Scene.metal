#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4 viewport; // pixels x/y, radius in pixels, center y from bottom
    float4 right;
    float4 up;
    float4 front;
    float4 sun;
    float4 style; // stars, Milky Way, atmosphere, night emission
    float4 moon; // center x/y pixels, radius pixels, projected lunar north
    float4 moonLight;
    float4 moonSurface; // libration lon/lat, illuminated fraction, reserved
};
struct VertexOut { float4 position [[position]]; };
vertex VertexOut sceneVertex(uint id [[vertex_id]]) {
    float2 p[] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
    return {float4(p[id], 0, 1)};
}
float hash21(float2 p) { return fract(sin(dot(p, float2(127.1,311.7))) * 43758.5453); }
float noise(float2 p) {
    float2 i = floor(p), f = fract(p); f = f*f*(3-2*f);
    return mix(mix(hash21(i),hash21(i+float2(1,0)),f.x),
               mix(hash21(i+float2(0,1)),hash21(i+1),f.x),f.y);
}
float3 starField(float2 pixel, constant Uniforms &u,texture2d<float> milkyWay) {
    // A stable angular field; no per-frame random generation or flashing stars.
    float2 p = pixel / min(u.viewport.x, u.viewport.y);
    float2 cell = floor(p * 520), local = fract(p * 520);
    float seed = hash21(cell);
    float2 center = float2(hash21(cell+8), hash21(cell+19));
    float star = exp(-dot(local-center,local-center) * 150) * step(0.989, seed);
    constexpr sampler sky(filter::linear,mip_filter::linear,s_address::repeat,t_address::clamp_to_edge);
    float2 skyUV = pixel/u.viewport.xy;
    float aspect = u.viewport.x/u.viewport.y;
    float2 q = skyUV-0.5; q.x *= aspect;
    constexpr float angle = -0.30;
    q = float2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y);
    q.x /= aspect; skyUV = q+float2(0.58,0.50);
    float3 panorama = milkyWay.sample(sky,skyUV).rgb;
    panorama = max(panorama-float3(0.004),0.0);
    float luminance = dot(panorama,float3(0.2126,0.7152,0.0722));
    panorama = mix(float3(luminance)*float3(0.78,0.86,1.0),panorama,0.42);
    float3 base = float3(0.0);
    return base + star * u.style.x * mix(float3(0.64,0.76,0.91),float3(1,0.88,0.73),seed)
        + panorama*u.style.y*0.38;
}
float2 sphericalUV(float3 n) {
    return float2(atan2(n.x,n.z)/(2*M_PI_F)+0.5, 0.5-asin(clamp(n.y,-1.0,1.0))/M_PI_F);
}
// Wrapped longitude derivatives avoid coarse mip stripes across the map seam.
float4 globeSample(texture2d<float> mapTexture,float2 uv) {
    constexpr sampler map(filter::linear,mip_filter::linear,s_address::repeat,t_address::clamp_to_edge);
    float2 dx = dfdx(uv), dy = dfdy(uv);
    dx.x -= round(dx.x); dy.x -= round(dy.x);
    return mapTexture.sample(map,uv,gradient2d(dx,dy));
}
float3 toWorld(float3 n, constant Uniforms &u) {
    return normalize(u.right.xyz*n.x + u.up.xyz*n.y + u.front.xyz*n.z);
}
float3 earthSurface(float3 n, constant Uniforms &u, texture2d<float> day,
                    texture2d<float> night, texture2d<float> clouds) {
    constexpr sampler map(filter::linear, mip_filter::linear, s_address::repeat, t_address::clamp_to_edge);
    float3 world = toWorld(n,u);
    float2 uv = sphericalUV(world);
    float solar = dot(world, u.sun.xyz);
    float diffuse = max(solar,0.0);
    float twilight = smoothstep(-0.105,0.045,solar);
    float3 albedo = globeSample(day,uv).rgb;
    float luminance = dot(albedo,float3(0.2126,0.7152,0.0722));
    albedo = mix(float3(luminance),albedo,0.84);
    float ocean = smoothstep(0.015,0.08,albedo.b-max(albedo.r,albedo.g));
    float3 halfDirection = normalize(u.sun.xyz+u.front.xyz);
    float specular = pow(max(0.0,dot(world,halfDirection)),90.0) * ocean * diffuse * 0.38;
    float3 nightFill = float3(0.045,0.085,0.19)*0.025;
    float3 color = albedo * (nightFill + twilight*0.05 + diffuse*1.6) + specular;
    // Preserve small towns as well as bright urban cores. A low mip adds a restrained halo.
    float3 lights = globeSample(night,uv).rgb;
    float3 bloom = night.sample(map,uv,level(3.0)).rgb;
    float emission = max(0.0, min(lights.r,lights.g*1.6)-lights.b*1.8);
    float halo = max(0.0,min(bloom.r,bloom.g*1.6)-bloom.b*1.8);
    float3 warm = float3(1.0,0.65,0.26)*emission;
    float nightVisibility = 1-smoothstep(-0.04,0.10,solar);
    color += lights*0.6*nightVisibility;
    color += (warm*1.4+float3(1.0,0.58,0.20)*halo*0.16) * u.style.w * nightVisibility;
    return color;
}
float3 moonSurface(float3 n, constant Uniforms &u, texture2d<float> moonMap) {
    constexpr sampler map(filter::linear, mip_filter::linear, s_address::repeat, t_address::clamp_to_edge);
    float ca = cos(u.moon.w), sa = sin(u.moon.w);
    float3 oriented = float3(ca*n.x-sa*n.y,sa*n.x+ca*n.y,n.z);
    float lon = (u.moonSurface.x*M_PI_F/180.0), lat = (u.moonSurface.y*M_PI_F/180.0);
    float3 right = float3(cos(lon),0,-sin(lon));
    float3 up = float3(-sin(lat)*sin(lon),cos(lat),-sin(lat)*cos(lon));
    float3 front = float3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon));
    float3 surface = right*oriented.x+up*oriented.y+front*oriented.z;
    float3 albedo = globeSample(moonMap,sphericalUV(surface)).rgb;
    float mu0 = max(0.0,dot(n,u.moonLight.xyz));
    float lunarDiffuse = mu0/(max(0.09,n.z)+mu0+0.001);
    return albedo*(0.018+1.15*lunarDiffuse);
}
float3 atmosphere(float2 p,float3 background,constant Uniforms &u) {
    constexpr float outer = 1.016;
    float r2 = dot(p,p);
    if (r2 >= outer*outer || u.style.z <= 0) return background;
    float farZ = sqrt(outer*outer-r2);
    float nearZ = r2 < 1 ? sqrt(1-r2) : -farZ;
    float stepLength = (farZ-nearZ)/6;
    float3 beta = float3(5.8,13.5,28.0);
    float viewDepth = 0;
    float3 scattering = 0;
    // Integrate toward the ground, accumulating the optical depth back to the observer.
    for (int i=0;i<6;i++) {
        float3 sampleView = float3(p,farZ-(i+0.5)*stepLength);
        float distance = length(sampleView);
        float3 world = (u.right.xyz*sampleView.x+u.up.xyz*sampleView.y+u.front.xyz*sampleView.z);
        float density = exp(-(distance-1)/0.003);
        float mu = dot(world,u.sun.xyz)/distance;
        float horizon = -sqrt(max(0.0,1.0-1.0/(distance*distance)));
        float shadow = smoothstep(horizon-0.012,horizon+0.012,mu);
        float sunDepth = density*0.003/max(0.08,mu+0.12);
        scattering += density*stepLength*exp(-beta*(viewDepth+sunDepth))*shadow;
        viewDepth += density*stepLength;
    }
    float cosAngle = dot(u.front.xyz,u.sun.xyz);
    float phase = 0.75*(1+cosAngle*cosAngle);
    return background*exp(-beta*viewDepth*u.style.z)
        + beta*scattering*phase*u.style.z*1.65;
}
fragment float4 sceneFragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]],
    texture2d<float> day [[texture(0)]], texture2d<float> night [[texture(1)]],
    texture2d<float> clouds [[texture(2)]], texture2d<float> moonMap [[texture(3)]],
    texture2d<float> milkyWay [[texture(4)]]) {
    float2 pixel = float2(in.position.x,u.viewport.y-in.position.y);
    float3 color = starField(pixel,u,milkyWay);
    float2 p = (pixel-float2(u.viewport.x*0.5,u.viewport.w))/u.viewport.z;
    float r = length(p);
    if (r < 1) {
        float3 n = float3(p,sqrt(max(0.0,1-r*r)));
        float coverage = smoothstep(0.0,1.5/u.viewport.z,1-r);
        color = mix(color,earthSurface(n,u,day,night,clouds),coverage);
    }
    // A second analytic sphere places clouds above the ground without a polygon seam.
    if (r < 1.007) {
        constexpr sampler map(filter::linear, mip_filter::linear, s_address::repeat, t_address::clamp_to_edge);
        float2 cp = p/1.007;
        float3 cn = float3(cp,sqrt(max(0.0,1-dot(cp,cp))));
        float3 world = toWorld(cn,u);
        float c = globeSample(clouds,sphericalUV(world)).r;
        float solar = dot(world,u.sun.xyz);
        float shade = 0.006+1.18*max(0.0,solar)+0.035*smoothstep(-0.08,0.06,solar);
        float alpha = smoothstep(0.08,0.96,c)*0.77*smoothstep(0.0,1.5/u.viewport.z,1.007-r);
        color = mix(color,float3(shade)*mix(float3(0.24,0.40,0.75),float3(0.92,0.97,1.0),smoothstep(-0.04,0.12,solar)),alpha);
    }
    color = atmosphere(p,color,u);
    if (u.moon.z > 0) {
        float2 p = (pixel-u.moon.xy)/u.moon.z;
        float rr = dot(p,p);
        if (rr < 1) {
            float3 n = float3(p,sqrt(max(0.0,1-rr)));
            float edge = smoothstep(0.0,1.5/u.moon.z,1-sqrt(rr));
            color = mix(color,moonSurface(n,u,moonMap),edge*u.moonSurface.w);
        }
    }
    return float4(1-exp(-color*1.18),1);
}
