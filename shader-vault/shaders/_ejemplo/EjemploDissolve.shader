Shader "Custom/EjemploDissolve"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _DissolveAmount ("Dissolve", Range(0,1)) = 0
        _EdgeColor ("Edge Color", Color) = (0,0.88,0.63,1)
        _EdgeWidth ("Edge Width", Range(0,0.2)) = 0.05
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

        struct Input {
            float2 uv_MainTex;
        };

        void surf(Input IN, inout SurfaceOutputStandard o) {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            half noise = tex2D(_NoiseTex, IN.uv_MainTex).r;
            half d = noise - _DissolveAmount;
            clip(d);
            half edge = smoothstep(0, _EdgeWidth, d);
            o.Emission = _EdgeColor.rgb * (1 - edge) * 3;
            o.Albedo = c.rgb;
            o.Alpha = c.a * edge;
        }
        ENDCG
    }
    FallBack "Transparent/Diffuse"
}
