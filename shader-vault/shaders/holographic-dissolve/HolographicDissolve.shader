Shader "Custom/HolographicDissolve"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _NoiseTex ("Noise", 2D) = "white" {}
        _DissolveAmount ("Dissolve", Range(0,1)) = 0
        _EdgeColor ("Edge Color", Color) = (0,0.88,0.63,1)
        _EdgeWidth ("Edge Width", Range(0,0.2)) = 0.05
        _FresnelPow ("Fresnel", Range(0.1,8)) = 3
        _ScanSpeed ("Scan Speed", Float) = 2.0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard alpha:fade
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _NoiseTex;
        fixed4 _Color;
        fixed4 _EdgeColor;
        half _DissolveAmount;
        half _EdgeWidth;
        half _FresnelPow;
        half _ScanSpeed;

        struct Input {
            float2 uv_MainTex;
            float3 worldPos;
            float3 viewDir;
        };

        void surf(Input IN, inout SurfaceOutputStandard o) {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            half noise = tex2D(_NoiseTex, IN.uv_MainTex).r;
            half d = noise - _DissolveAmount;
            clip(d);

            half edge = smoothstep(0, _EdgeWidth, d);
            o.Emission = _EdgeColor.rgb * (1 - edge) * 3;

            half rim = 1 - saturate(dot(IN.viewDir, o.Normal));
            o.Emission += _EdgeColor * pow(rim, _FresnelPow);

            o.Albedo = c.rgb;
            o.Alpha = c.a * edge;
        }
        ENDCG
    }
    FallBack "Transparent/Diffuse"
}
