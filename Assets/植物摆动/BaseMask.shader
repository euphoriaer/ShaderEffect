Shader "Custom/BaseMask" {
	Properties
	{ [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("SrcBlend", Float) = 5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("DstBlend", Float) = 10
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTestMode("ZTestMode", Float) = 4
		[Enum(Off, 0, On, 1)]_ZWriteMode("ZWriteMode", float) = 1
		[MainTexture] _MainTex("Albedo", 2D) = "white" {}
		[MainColor] _Color("基础颜色", Color) = (1,1,1,1)
		[Toggle(_MASK)]_MASK("CustomMask", int) = 0
		_MapVector("地图坐标和尺寸", Vector) = (0,0,1,1)
		_MaskTexture("Mask", 2D) = "white" {}
		_DiscardAlpha("裁剪Alpha值", range(0,1)) = 0.1
		[Toggle(_EMISSION)]_Emission("自发光", int) = 0
		 [HDR] _EmissionColor("自发光颜色", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "black" {}

		_LutTex("LutTexture", 2D) = "white" {}
		_LutRatio("LutRatio", float) = 0

		_MaskTan("MaskTan", float) = 0.0
		_MASKA("使用MaskA通道", int) = 0
		_UseNewMASK("UseNewMASK", int) = 0
		[HDR]_MaskEndColor("MaskEndColor", Color) = (1,1,1)
		[HDR]_MaskEndColorR("MaskEndColorR", Color) = (1,1,1)
		[HDR]_MaskEndColorG("MaskEndColorG", Color) = (1,1,1)
		[HDR]_MaskEndColorB("MaskEndColorB", Color) = (1,1,1)
		_MaskEndBrightness("MaskEndBrightness", float) = 1.0
		_MaskEndBrightnessR("MaskEndBrightnessR", float) = 1.0
		_MaskEndBrightnessG("MaskEndBrightnessG", float) = 1.0
		_MaskEndBrightnessB("MaskEndBrightnessB", float) = 1.0

		_CloudShadowSpeed("CloudShadowSpeed", Vector) = (0,0,0,0)
		_CloudShadowOffset("CloudShadowOffset", Vector) = (0,0,0,0)
		[Toggle(_WIND)]_WIND("WindMask", int) = 0
		_Speed("Speed", Float) = 10
		_Move("Move", Float) = 0
		_num("Warp", Float) = 10
		_Strength("Strength", Float) = 10
		
	}

		SubShader
		{
			Pass
			{
				Tags{"RenderPipeline" = "UniversalPipeline"
					"RenderType" = "Opaque"
					"IgnoreProjector" = "True"
					"Queue" = "Opaque"}
				LOD 300
				Blend[_SrcBlend][_DstBlend]
				ZWrite[_ZWriteMode]
				ZTest[_ZTestMode]
				Cull Off
				Name "Unlit"
				HLSLPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

				#pragma multi_compile _ _MASK
				#pragma multi_compile _ _WIND
				#pragma shader_feature_local_fragment _EMISSION

				half4 _Color;
				half _Alpha;
				TEXTURE2D(_MainTex);
				SAMPLER(sampler_MainTex);
				half4 _MainTex_ST;

				TEXTURE2D(_LutTex);
				float _DiscardAlpha;
				SamplerState sampler_LinearClamp;
				half _LutRatio;

				TEXTURE2D(_EmissionMap);
				SAMPLER(sampler_EmissionMap);

				half3 _EmissionColor;
				#if _MASK 
					sampler2D _MaskTexture;
					float _MaskTan;
					int _MASKA;
					int _UseNewMASK;
					float4 _MaskTexture_ST;
					float4 _MapVector;
					float3 _MaskEndColor;
					float3 _MaskEndColorR;
					float3 _MaskEndColorG;
					float3 _MaskEndColorB;
					half _MaskEndBrightness;
					half _MaskEndBrightnessR;
					half _MaskEndBrightnessG;
					half _MaskEndBrightnessB;



					float2 _CloudShadowSpeed;
					float2 _CloudShadowOffset;
				#endif

		
				#if _WIND
					float _num;
					float _Speed;
					float _Move;
					float _Strength;
					float _Range;
				#endif
				struct VertexInput
				{
					float4 vertex       : POSITION;
					float2 uv0               : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct VertexOutput
				{
					float4 clipPos : SV_POSITION;
					float2 uv        : TEXCOORD0;
					float3 positionWS               : TEXCOORD1;
					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
				};

				float2 voronoihash25(float2 p)
				{

					p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
					return frac(sin(p) * 43758.5453);
				}

				float voronoi25(float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId)
				{
					float2 n = floor(v);
					float2 f = frac(v);
					float F1 = 8.0;
					float F2 = 8.0; float2 mg = 0;
					for (int j = -1; j <= 1; j++)
					{
						for (int i = -1; i <= 1; i++)
						{
							float2 g = float2(i, j);
							float2 o = voronoihash25(n + g);
							o = (sin(time + o * 6.2831) * 0.5 + 0.5); float2 r = f - g - o;
							float d = 0.5 * dot(r, r);
							if (d < F1) {
								F2 = F1;
								F1 = d; mg = g; mr = r; id = o;
							}
							else if (d < F2) {
								F2 = d;

							}
						}
					}
					return F1;
				}

				VertexOutput vert(VertexInput v)
				{
					VertexOutput o = (VertexOutput)0;
					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_TRANSFER_INSTANCE_ID(v, o);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

					//Wind 顶点偏移 
#if _WIND

					float time25 = ((_TimeParameters.x) * _Speed);
					float2 voronoiSmoothId0 = 0;
					float2 texCoord26 = v.uv0.xy * float2(1, 1) + float2(0, 0);
					float2 coords25 = texCoord26 * _num;
					float2 id25 = 0;
					float2 uv25 = 0;
					float voroi25 = voronoi25(coords25, time25, id25, uv25, 0, voronoiSmoothId0);
					float2 texCoord45 = v.uv0.xy * float2(1, 1) + float2(0, 0);
					float clampResult = clamp((texCoord45.y - _Range), 0.0, 1.0);
					float temp_output_49_0 = (((voroi25 - _Move) * _Strength) * clampResult);
					float3 objToWorld11 = mul(GetObjectToWorldMatrix(), float4(float3(0, 0, 0), 1)).xyz;
					float3 appendResult29 = (float3(temp_output_49_0, objToWorld11.y, objToWorld11.z));

					float3 vertexValue = appendResult29;
					
					
					v.vertex.xyz += vertexValue;
					
#endif
					VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
					o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
					o.positionWS = TransformObjectToWorld(v.vertex.xyz);
					o.clipPos = TransformWorldToHClip(o.positionWS);
					return o;
				}

				half RGBToL(half3 color)
				{
					half fmin = min(min(color.r, color.g), color.b);    //Min. value of RGB
					half fmax = max(max(color.r, color.g), color.b);    //Max. value of RGB

					return (fmax + fmin) / 2.0; // Luminance
				}

				half3 RGBToHSL(half3 color)
				{
					half3 hsl; // init to 0 to avoid warnings ? (and reverse if + remove first part)

					half fmin = min(min(color.r, color.g), color.b);    //Min. value of RGB
					half fmax = max(max(color.r, color.g), color.b);    //Max. value of RGB
					half delta = fmax - fmin;             //Delta RGB value

					hsl.z = (fmax + fmin) / 2.0; // Luminance

					if (delta == 0.0)		//This is a gray, no chroma...
					{
						hsl.x = 0.0;	// Hue
						hsl.y = 0.0;	// Saturation
					}
					else                                    //Chromatic data...
					{
						if (hsl.z < 0.5)
							hsl.y = delta / (fmax + fmin); // Saturation
						else
							hsl.y = delta / (2.0 - fmax - fmin); // Saturation

						half deltaR = (((fmax - color.r) / 6.0) + (delta / 2.0)) / delta;
						half deltaG = (((fmax - color.g) / 6.0) + (delta / 2.0)) / delta;
						half deltaB = (((fmax - color.b) / 6.0) + (delta / 2.0)) / delta;

						if (color.r == fmax)
							hsl.x = deltaB - deltaG; // Hue
						else if (color.g == fmax)
							hsl.x = (1.0 / 3.0) + deltaR - deltaB; // Hue
						else if (color.b == fmax)
							hsl.x = (2.0 / 3.0) + deltaG - deltaR; // Hue

						if (hsl.x < 0.0)
							hsl.x += 1.0; // Hue
						else if (hsl.x > 1.0)
							hsl.x -= 1.0; // Hue
					}

					return hsl;
				}

				half HueToRGB(half f1, half f2, half hue)
				{
					if (hue < 0.0)
						hue += 1.0;
					else if (hue > 1.0)
						hue -= 1.0;
					half res;
					if ((6.0 * hue) < 1.0)
						res = f1 + (f2 - f1) * 6.0 * hue;
					else if ((2.0 * hue) < 1.0)
						res = f2;
					else if ((3.0 * hue) < 2.0)
						res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
					else
						res = f1;
					return res;
				}

				half3 HSLToRGB(half3 hsl)
				{
					half3 rgb;

					if (hsl.y == 0.0)
						rgb = half3(hsl.z, hsl.z, hsl.z); // Luminance
					else
					{
						half f2;

						if (hsl.z < 0.5)
							f2 = hsl.z * (1.0 + hsl.y);
						else
							f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);

						half f1 = 2.0 * hsl.z - f2;

						rgb.r = HueToRGB(f1, f2, hsl.x + (1.0 / 3.0));
						rgb.g = HueToRGB(f1, f2, hsl.x);
						rgb.b = HueToRGB(f1, f2, hsl.x - (1.0 / 3.0));
					}

					return rgb;
				}

				half3 SampleEmission(float2 uv, half3 emissionColor, TEXTURE2D_PARAM(emissionMap, sampler_emissionMap))
				{
				#ifndef _EMISSION
					return 0;
				#else
					return SAMPLE_TEXTURE2D(emissionMap, sampler_emissionMap, uv).rgb * emissionColor;
				#endif
				}

				half4 frag(VertexOutput input) : SV_Target
				{
					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
					half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
					c *= _Color;

					//(1f / lut.width, 1f / lut.height, lut.height - 1f)
					float3 userLutParams = float3(1.0 / 256, 1.0 / 16, 15);

					c.rgb = LinearToSRGB(c.rgb);
					half3 outLut = ApplyLut2D(TEXTURE2D_ARGS(_LutTex, sampler_LinearClamp), c.rgb, userLutParams);
					c.rgb = lerp(c.rgb, outLut, _LutRatio);
					c.rgb = SRGBToLinear(c.rgb);

					#if _MASK 
						half3 pos = input.positionWS;
						pos.x -= _MapVector.x;
						pos.z -= _MapVector.y - pos.y * _MaskTan;
						half2 uv = half2(0,0);
						uv.x = saturate((pos.x + 0.5 * _MapVector.z) / _MapVector.z);
						uv.y = saturate((pos.z + 0.5 * _MapVector.w) / _MapVector.w);
						half4 mask = tex2D(_MaskTexture, uv);

						half2 cloudUV = uv;
						cloudUV.x += _CloudShadowSpeed.x * _Time.x + _CloudShadowOffset.x;
						cloudUV.y += _CloudShadowSpeed.y * _Time.x + _CloudShadowOffset.y;
						half4 cloudMask = tex2D(_MaskTexture, cloudUV);

						float cloudA = cloudMask.a * _MASKA;
						float shadow = max(cloudA, mask.r);
						half shadowEndBrightness;
						float3 shadowEndColor;
						if (cloudA > mask.r)
						{
							shadowEndBrightness = _MaskEndBrightness;
							shadowEndColor = _MaskEndColor;
						}
						else
						{
							shadowEndBrightness = _MaskEndBrightnessR;
							shadowEndColor = _MaskEndColorR;
						}
						c.rgb = c.rgb * (1 - shadow) + c.rgb * shadowEndColor * shadow * shadowEndBrightness;

						c.rgb = c.rgb * (1 - mask.g) + c.rgb * _MaskEndColorG * mask.g * _MaskEndBrightnessG;
						c.rgb = c.rgb * (1 - mask.b) + c.rgb * _MaskEndColorB * mask.b * _MaskEndBrightnessB;
					#endif
					half3  emission = SampleEmission(input.uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
					c.rgb += emission;
					c.rgb = saturate(c.rgb);
					if (c.a < _DiscardAlpha) discard;
					return c;
				}

				ENDHLSL
			}
		}
			FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
