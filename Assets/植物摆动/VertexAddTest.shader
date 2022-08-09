Shader "V/URP/Tessellation"
{
    Properties
    {
        _Color("Color(RGB)",Color) = (1,1,1,1)
        _MainTex("MainTex",2D) = "gary"{}
        _Tess("Tessellation", Range(1, 32)) = 20
        _MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1
    }
        SubShader
        {
            Tags
            {
                "RenderPipeline" = "UniversalPipeline"
                "RenderType" = "Opaque"
                "Queue" = "Geometry+0"
            }

            Pass
            {
                Name "Pass"
                Tags
                {

                }

                // Render State
                Blend One Zero, One Zero
                Cull Back
                ZTest LEqual
                ZWrite On

                HLSLPROGRAM

                #pragma require tessellation
                #pragma require geometry

                #pragma vertex BeforeTessVertProgram
                #pragma hull HullProgram
                #pragma domain DomainProgram
                #pragma fragment FragmentProgram

                #pragma prefer_hlslcc gles
                #pragma exclude_renderers d3d11_9x
                #pragma target 4.6

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            float _Tess;
            float _MaxTessDistance;
            float _MinTessDistance;
            CBUFFER_END

            Texture2D _MainTex;
            float4 _MainTex_ST;

            //Ϊ�˷������ ����Ԥ����
            #define smp SamplerState_Point_Repeat
            // SAMPLER(sampler_MainTex); Ĭ�ϲ�����
            SAMPLER(smp);

            // ������ɫ��������
            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            // Ƭ����ɫ��������
            struct Varyings
            {
                float4 color : COLOR;
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posWS:TEXCOORD1;
            };

            // Ϊ��ȷ�����ϸ�������Σ�GPUʹ�����ĸ�ϸ�����ӡ���������Ƭ��ÿ����Ե����һ��������
            // �����ε��ڲ�Ҳ��һ�����ء�������Ե����������Ϊ����SV_TessFactor�����float���鴫�ݡ�
            // �ڲ�����ʹ��SV_InsideTessFactor����
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // �ýṹ�����ಿ����Attributes��ͬ��ֻ��ʹ��INTERNALTESSPOS����POSITION���⣬����������ᱨλ�����������
            struct ControlPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normal : NORMAL;
            };

            // ������ɫ������ʱֻ�ǽ�Attributes������ݵݽ�������ϸ�ֽ׶�
            ControlPoint BeforeTessVertProgram(Attributes v)
            {
                ControlPoint p;

                p.vertex = v.vertex;
                p.uv = v.uv;
                p.normal = v.normal;
                p.color = v.color;

                return p;
            }

            // ���ž�����ľ������ϸ����
            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float3 worldPosition = TransformObjectToWorld(vertex.xyz);
                float dist = distance(worldPosition,  GetCameraPositionWS());
                float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                return (f);
            }

            // Patch Constant Function����Patch�����������ϸ�ֵġ�����ζ����ÿ��Patch��������һ�Σ�
            // ������ÿ�����Ƶ㱻����һ�Ρ������Ϊʲô������Ϊ����������������Patch�ж��ǳ�����ԭ��
            // ʵ���ϣ��˹�������HullProgram�������е��ӽ׶Ρ�
            // ��������Ƭ��ϸ�ַ�ʽ����ϸ�����ӿ��ơ�������MyPatchConstantFunction��ȷ����Щ���ء�
            // ��ǰ�����Ǹ�������������λ��������ϸ������
            TessellationFactors MyPatchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                float minDist = _MinTessDistance;
                float maxDist = _MaxTessDistance;

                TessellationFactors f;

                float edge0 = CalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess);

                // make sure there are no gaps between different tessellated distances, by averaging the edges out.
                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            //ϸ�ֽ׶ηǳ������Դ��������Σ��ı��λ��ֵ�ߡ����Ǳ������������ʹ��ʲô���沢�ṩ��Ҫ�����ݡ�
            //���� hull ����Ĺ�����Hull ���������油�������У������油����Ϊ�������ݸ�����
            //���Ǳ������һ��InputPatch��������ʵ����һ�㡣Patch�����񶥵�ļ��ϡ�����ָ����������ݸ�ʽ��
            //���ڣ����ǽ�ʹ��ControlPoint�ṹ���ڴ���������ʱ��ÿ�������������������㡣����������ָ��ΪInputPatch�ĵڶ���ģ�����
            //Hull����Ĺ����ǽ�����Ķ������ݴ��ݵ�ϸ�ֽ׶Ρ����������ṩ������������
            //���ú���һ�ν�Ӧ���һ�����㡣�����е�ÿ�����㶼�����һ������������һ�����Ӳ�����
            //�ò���ָ��Ӧ��ʹ���ĸ����Ƶ㣨���㣩���ò����Ǿ���SV_OutputControlPointID������޷���������
            [domain("tri")]//��ȷ�ظ��߱��������ڴ��������Σ�����ѡ�
            [outputcontrolpoints(3)]//��ȷ�ظ��߱�����ÿ����������������Ƶ�
            [outputtopology("triangle_cw")]//��GPU������������ʱ������Ҫ֪�������Ƿ�Ҫ��˳ʱ�����ʱ�붨������
            [partitioning("fractional_odd")]//��֪GPUӦ����ηָ�������ڣ���ʹ������ģʽ
            [patchconstantfunc("MyPatchConstantFunction")]//GPU������֪��Ӧ�������гɶ��ٲ��֡��ⲻ��һ���㶨ֵ��ÿ����������������ͬ�������ṩһ��������ֵ�ĺ�������Ϊ��������������Patch Constant Functions��
            ControlPoint HullProgram(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            Varyings AfterTessVertProgram(Attributes v)
            {
                Varyings o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.posWS = TransformObjectToWorld(v.vertex);

                return o;
            }

            //HUll��ɫ��ֻ��ʹ����ϸ�ֹ��������һ���֡�һ��ϸ�ֽ׶�ȷ����Ӧ���ϸ�ֲ�����
            //����Domain��ɫ��������������������������εĶ��㡣
            //Domain���򽫻��ʹ�õ�ϸ�������Լ�ԭʼ��������Ϣ��ԭʼ���������������ΪOutputPatch���͡�
            //ϸ�ֽ׶�ȷ��������ϸ�ַ�ʽʱ����������κ��µĶ��㡣�෴������Ϊ��Щ�����ṩ�������ꡣ
            //ʹ����Щ�������������ն���ȡ��������ɫ����Ϊ��ʹ֮��Ϊ���ܣ�ÿ�����㶼�����һ����������Ϊ���ṩ�������ꡣ
            //���Ǿ���SV_DomainLocation���塣
            //��Demain�������棬���Ǳ����������յĶ������ݡ�
            [domain("tri")]//Hull��ɫ����Domain��ɫ������������ͬ���򣬼������Ρ�����ͨ��domain�����ٴη����ź�
            Varyings DomainProgram(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Attributes v;

                //Ϊ���ҵ��ö����λ�ã����Ǳ���ʹ������������ԭʼ�����η�Χ�ڽ��в�ֵ��
                //X��Y��Z����ȷ����һ���ڶ��͵������Ƶ��Ȩ�ء�
                //����ͬ�ķ�ʽ��ֵ���ж������ݡ�������Ϊ�˶���һ������ĺ꣬�ú����������ʸ����С��
                #define DomainInterpolate(fieldName) v.fieldName = \
                        patch[0].fieldName * barycentricCoordinates.x + \
                        patch[1].fieldName * barycentricCoordinates.y + \
                        patch[2].fieldName * barycentricCoordinates.z;

                    //��λ�á���ɫ��UV�����ߵȽ��в�ֵ
                    DomainInterpolate(vertex)
                    DomainInterpolate(uv)
                    DomainInterpolate(color)
                    DomainInterpolate(normal)

                        //���ڣ���������һ���µĶ��㣬�ö��㽫�ڴ˽׶�֮���͵����γ�����ֵ����
                        //������Щ������ҪVaryings���ݣ�������Attributes��Ϊ�˽��������⣬
                        //����������ɫ���ӹ���ԭʼ��������ְ��
                        //����ͨ���������е�AfterTessVertProgram���������κκ���һ������������������ɵġ�
                        return AfterTessVertProgram(v);
                }

            // Ƭ����ɫ��
            half4 FragmentProgram(Varyings i) : SV_TARGET
            {
                half4 mainTex = _MainTex.Sample(smp,i.uv);
                half4 c = _Color * mainTex;

                return c;
            }

            ENDHLSL
        }
        }
}