Shader "URP/ToonOutline" {
    Properties
    {
        [MainTexture] _MainTex ("主纹理", 2D) = "white" {}
        [MainColor] _BaseColor ("颜色", Color) = (1,1,1,1)
        _NormalMap ("法线贴图", 2D) = "bump" {}
        _NormalStrength ("法线强度", Range(0,2)) = 1
        
        // 轮廓线参数
        [Toggle(USE_OUTLINE)] _UseOutline ("启用轮廓线", Float) = 0
        _OutlineColor ("轮廓颜色", Color) = (0,0,0,1)
        _OutlineWidth ("轮廓宽度", Range(0, 1)) = 0.05
        
        // 边缘光参数
        _FresnelColor ("菲涅尔颜色", Color) = (1,1,1,1)
        _FresnelPower ("菲涅尔强度", Range(0, 10)) = 5
        _FresnelIntensity ("菲涅尔亮度", Range(0, 1)) = 0.5
        
        // 色阶参数
        _CelShadingMidLevel ("色阶中值", Range(0,1)) = 0.5
        _CelShadingSoftness ("色阶柔化", Range(0,0.5)) = 0.05
        
        //阴影接受
        _ReceiveShadowIntensity("阴影强度", Range(0,1)) = 0.5
        _ShadowSmoothness("阴影平滑度", Range(0,0.3)) = 0.1
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            ZWrite On
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature USE_OUTLINE
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                float _OutlineWidth;
                float4 _OutlineColor;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                #ifdef USE_OUTLINE
                    // 在视图空间计算轮廓挤出
                    float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, input.normalOS);
                    float3 viewPos = mul(UNITY_MATRIX_MV, input.positionOS);
                    viewPos += normalize(viewNormal) * _OutlineWidth * 0.01;
                    output.positionCS = mul(UNITY_MATRIX_P, float4(viewPos, 1.0));
                #else
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                #endif
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                #ifdef USE_OUTLINE
                    return _OutlineColor;
                #else
                    return half4(0,0,0,0);
                #endif
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ColorMask 0 // 禁用颜色写入
            Cull Back

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                
                // 获取顶点位置
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                
                // 应用阴影偏移
                float3 positionWS = positionInputs.positionWS;
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                positionWS = ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz);
                output.positionCS = TransformWorldToHClip(positionWS);
                
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }

        // 主渲染Pass
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back
             
            HLSLPROGRAM
             #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
               float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float3 tangentWS : TEXCOORD4;
                float3 bitangentWS : TEXCOORD5;
                float4 shadowCoord : TEXCOORD6;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float4 _FresnelColor;
                float _FresnelPower;
                float _FresnelIntensity;
                float _CelShadingMidLevel;
                float _CelShadingSoftness;
                float _NormalStrength;
                float _ReceiveShadowIntensity;
                float _ShadowSmoothness;
            CBUFFER_END


             
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = normalInputs.tangentWS;
                output.bitangentWS = normalInputs.bitangentWS;
                
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(output.positionWS);
                
                output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                Light mainLight = GetMainLight();

                // 法线计算
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalStrength);
                float3x3 TBN = float3x3(normalize(input.tangentWS), normalize(input.bitangentWS), normalize(input.normalWS));
                float3 normalWS = TransformTangentToWorld(normalTS, TBN);
                normalWS = normalize(normalWS);
                
                // 光照计算
                float3 lightDir = normalize(mainLight.direction);
                float NdotL = dot(normalWS, lightDir);
                
                // 色阶处理（必须先计算）
                float celShading = smoothstep( // <--- 这里需要先声明和计算
                    _CelShadingMidLevel - _CelShadingSoftness,
                    _CelShadingMidLevel + _CelShadingSoftness,
                    NdotL * 0.5 + 0.5
                );
                
                // 阴影计算（必须在celShading之后）
                float shadow = mainLight.shadowAttenuation;
                shadow = smoothstep(
                    shadow - _ShadowSmoothness,
                    shadow + _ShadowSmoothness,
                    shadow
                );
                shadow = lerp(1.0, shadow, _ReceiveShadowIntensity); // <--- 正确顺序
                
                // 直接光照（现在可以正确使用celShading）
                float3 directLighting = mainLight.color * celShading * shadow; 
                           
                
                // 基础颜色
                float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _BaseColor;
                
                // 边缘光计算
                float3 viewDir = normalize(input.viewDirWS);
                float fresnel = pow(1.0 - saturate(dot(normalWS, viewDir)), _FresnelPower) * _FresnelIntensity;
                float3 fresnelColor = fresnel * _FresnelColor.rgb;
                
                // 最终颜色合成
                float3 finalColor = baseColor.rgb * (directLighting + fresnelColor);
                
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
}