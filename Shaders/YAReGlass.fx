/*
  LookingGlass by Jared Bienz. Based on the incredible DisplayDepth Fx originally 
  created by CeeJay.dk (with many updates and additions by the Reshade community).
  Version 1.1 also now leverages GaussianBlur by Ioxa to smooth out the depth map. 
  
  Thank you!

  Visualizes color and depth in a format ready to be imported into HoloPlay Studio.
*/

#include "ReShade.fxh"

// -- Help Text --

#if __RESHADE__ >= 40500 // If Reshade version is above or equal to 4.5
	/*
	#if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
		#define UPSIDE_DOWN_HELP_TEXT "RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN is currently set to 1.\n"\
			"If the depth map is upside down, change this to 0."
	#else
		#define UPSIDE_DOWN_HELP_TEXT "RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN is currently set to 0.\n"\
			"If the depth map is upside down, change this to 1."
	#endif
	
	#if RESHADE_DEPTH_INPUT_IS_REVERSED
		#define REVERSED_HELP_TEXT "RESHADE_DEPTH_INPUT_IS_REVERSED is currently set to 1.\n"\
			"If near objects are dark and far objects are bright, change this to 0."
	#else
		#define REVERSED_HELP_TEXT "RESHADE_DEPTH_INPUT_IS_REVERSED is currently set to 0.\n"\
			"If near objects are dark and far objects are bright, change this to 1."
	#endif
	
	#if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
		#define LOGARITHMIC_HELP_TEXT "RESHADE_DEPTH_INPUT_IS_LOGARITHMIC is currently set to 1.\n"\
			"If the depth map has banding artifacts (extra stripes) change this to 0."
	#else
		#define LOGARITHMIC_HELP_TEXT "RESHADE_DEPTH_INPUT_IS_LOGARITHMIC is currently set to 0.\n"\
			"If the depth map has banding artifacts (extra stripes) change this to 1."
	#endif
	*/

	#if REGLASS_OUTPUT_IS_CHROMA
		#define DEPTH_OUTPUT_CHROMA_TEXT "REGLASS_OUTPUT_IS_CHROMA := 1"
	#else
		#define DEPTH_OUTPUT_CHROMA_TEXT "REGLASS_OUTPUT_IS_CHROMA := 0"
	#endif

	uniform int LG_about <
		ui_category = "About";
		ui_category_closed = true;
		nosave = true;
		ui_type = "radio"; ui_label = " ";
		ui_text =
			"These settings configure how your screen should appear when taking screenshots for Looking Glass.\n"
			"\n"
			"Using the sliders below, try to achieve a full range of bright white to grey to black. When ready,\n"
			"make sure to use ReShade to take the screenshot and not the game itself.\n";
	>;

	uniform int LG_Preprocessor_Definition <
		ui_category = "Preprocessor Definition"; 
		ui_category_closed = true;		
		ui_type = "radio"; ui_label = " ";
		nosave = true;
		ui_text =
			"These preprocessor definition changes this effect behavior.\n"
			"\n"
			DEPTH_OUTPUT_CHROMA_TEXT "\n";
	>;	
#endif

// -- Options --

uniform bool bDebugFlag <
	ui_label = "Use debug display";
	ui_tooltip = "Display region for nearclip(red), farclip(blue), focusplane(green).";
	nosave = true;
> = false;

uniform float fUIFarFactor <
	ui_type = "drag";
	ui_label = "Far factor";
	//ui_tooltip = "A value that is used where should be more important.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

// Caution: 0.0 is less emphasize.
uniform float fUIGammaFactor <
	ui_type = "drag";
	ui_label = "Gain factor";
	ui_tooltip = "A factor to emphasize depth value.";
	ui_step = 0.001;
	ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform bool bUIIsUseClip <
	ui_category = "Clipping";
	ui_label = "Enable clipping";
	ui_category_toggle = true;
> = false;

uniform int iUIClipType <
	ui_category = "Clipping";
	ui_type = "combo";
	ui_label = "Clipping type";
	ui_tooltip = "Method to apply cliping.";
	ui_items = "Simple\0Smoothstep\0";
> = 0;

uniform float fNearClip <
	ui_category = "Clipping";
	ui_type = "drag";
	ui_label = "Near clip position";
	ui_tooltip = "If original depth value is less than this, it will clamp at 0.0.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.0001;
> = 0.0;

uniform float fFarClip <
	ui_category = "Clipping";
	ui_type = "drag";
	ui_label = "Far clip position";
	ui_tooltip = "If original depth value is greater than this, it will clamp at 1.0.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.0005;
> = 1.0;

uniform bool bUIIsUseAutoFocus <
	ui_category = "Auto focus";
	ui_label = "Enable auto focusing";
	ui_category_toggle = true;
> = false;

uniform bool bUIShowFocusPoint <
	ui_category = "Auto focus";
	ui_label = "Display focus point";
> = false;

uniform bool bUIDisableDisplayDepth <
	ui_category = "Auto focus";
	ui_label = "Don't display depth";
	no_save = true;
> = false;

uniform int iAutoFocusTargetX <
	ui_category = "Auto focus";
	ui_label = "Auto focus target X pos";
	ui_type = "drag";
	ui_min = 0; ui_max = BUFFER_WIDTH - 1;
	ui_step = 1;
	ui_units = "px";
> = BUFFER_WIDTH / 2;

uniform int iAutoFocusTargetY <
	ui_category = "Auto focus";
	ui_label = "Auto focus target Y pos";
	ui_type = "drag";
	ui_min = 0; ui_max = BUFFER_HEIGHT - 1;
	ui_step = 1;
	ui_units = "px";
> = BUFFER_HEIGHT / 2;

uniform float fAutoFocusTargetDepth <
	ui_category = "Auto focus";
	ui_type = "drag";
	ui_label = "Target depth value";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

uniform float fAutoFocusPermissiveWidth <
	ui_category = "Auto focus";
	ui_type = "drag";
	ui_label = "Permissive width";
	ui_min = 0.0; ui_max = 0.5;
	ui_step = 0.001;
> = 0.01;

uniform float fAutoFocusGraceDuration <
	ui_category = "Auto focus";
	ui_type = "drag";
	ui_label = "Grace duration (ms)";
	ui_min = 0.0; ui_max = 6000.0;
	ui_step = 100.0;
> = 500.0;

/*
uniform float fAutoFocusSpeed <
	ui_category = "Auto focus";
	ui_type = "drag";
	ui_label = "Speed";
	ui_min = 0.1; ui_max = 1.0;
	ui_step = 0.1;
	hidden = true;
> = 1.0;
*/
static const float fAutoFocusSpeed = 1.0;

uniform int GaussianBlurRadius <
	ui_category = "Gaussian Blur";
	ui_type = "drag";
	ui_label = "Blur Radius";
	ui_tooltip = "How many neighboring pixels influence the original pixel.";
	ui_min = 0.0; ui_max = 4.0;
	ui_step = 1.0;
> = 4;

uniform float GaussianBlurStrength <
	ui_category = "Gaussian Blur";
	ui_type = "drag";
	ui_label = "Blur Strength";
	ui_tooltip = "How strongly do neighboring pixels influence the original pixel.";
	ui_min = 0.00; ui_max = 1.00;
	ui_step = 0.001;
> = 1.000;

uniform float GaussianBlurOffset <
	ui_category = "Gaussian Blur";
	ui_type = "drag";
	ui_label = "Blur Offset";
	ui_tooltip = "Can be used to fine-tune the 'crispness' of the edge.";
	ui_min = 0.00; ui_max = 2.00;
	ui_step = 0.001;
> = 0.5;

uniform float XOffset <
	ui_type = "drag";
	ui_label = "X Offset";
	ui_tooltip = "Can be use to X position.";
	ui_min = -1.00; ui_max = 1.00;
	ui_step = 0.001;
> = 0.0;

uniform float fTimer <
	source = "timer";
>;

// -- Variables --

texture GaussianBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler GaussianBlurSampler { Texture = GaussianBlurTex;};

texture ConvertedDepthTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16F; };
sampler ConvertedDepthSampler { Texture = ConvertedDepthTex; };

texture PreviousModifiedDepthT { Width = 1; Height = 1; Format = RG16F; };
sampler PreviousModifiedDepthS { Texture = PreviousModifiedDepthT; };

texture CurrentModifiedDepthT { Width = 1; Height = 1; Format = RG16F; };
sampler CurrentModifiedDepthS { Texture = CurrentModifiedDepthT; };

static const float PERMISSIVE_SPEED_DIVIDER = 3.0;

static const float4 FOCUS_POINT_RUNNING_COLOR = float4(0.0, 1.0, 1.0, 0.8);
static const float4 FOCUS_POINT_STOPPED_COLOR = float4(1.0, 1.0, 0.0, 0.8);
static const float2 FOCUS_POINT_HALFSIZE = float2(BUFFER_RCP_WIDTH * 5, BUFFER_RCP_HEIGHT * 5);

static const float4 DEBUG_NEAR_CLIP_COLOR = float4(1.0, 0.0, 0.0, 0.7);
static const float4 DEBUG_FAR_CLIP_COLOR = float4(0.0, 0.0, 1.0, 0.7);
static const float4 DEBUG_FOCUS_PLANE_COLOR = float4(0.0, 1.0, 0.0, 0.2);
static const float4 DEBUG_FOCUS_DIFF_COLOR = float4(0.0, 1.0, 0.5, 0.8);

// -- Blur Functions --

float3 GaussianBlurFinal(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	// Get color from the sampler
	float3 color = tex2D(GaussianBlurSampler, texcoord).rgb;
	if (bUIDisableDisplayDepth) {
		return color;
	}

	// Only blur the right side. If this is the left side, just return the current color and skip all processing.
	if (pos.x <= (BUFFER_WIDTH * 0.5)) { return color; }
	
	if(GaussianBlurRadius == 0)	
	{
		float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
		float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 4; ++i)
		{
			color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
		}
	}	

	if(GaussianBlurRadius == 1)	
	{
		float offset[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
		float weight[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 6; ++i)
		{
			color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
		}
	}	

	if(GaussianBlurRadius == 2)	
	{
		float offset[11] = { 0.0, 1.4895848401, 3.4757135714, 5.4618796741, 7.4481042327, 9.4344079746, 11.420811147, 13.4073334, 15.3939936778, 17.3808101174, 19.3677999584 };
		float weight[11] = { 0.06649, 0.1284697563, 0.111918249, 0.0873132676, 0.0610011113, 0.0381655709, 0.0213835661, 0.0107290241, 0.0048206869, 0.0019396469, 0.0006988718 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 11; ++i)
		{
			color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
		}
	}	

	if(GaussianBlurRadius == 3)	
	{
		float offset[15] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4401038149, 21.43402885, 23.4279736431, 25.4219399344, 27.4159294386 };
		float weight[15] = { 0.0443266667, 0.0872994708, 0.0820892038, 0.0734818355, 0.0626171681, 0.0507956191, 0.0392263968, 0.0288369812, 0.0201808877, 0.0134446557, 0.0085266392, 0.0051478359, 0.0029586248, 0.0016187257, 0.0008430913 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 15; ++i)
		{
			color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
		}
	}

	if(GaussianBlurRadius == 4)	
	{
		float offset[18] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4661974725, 21.4627427973, 23.4592916956, 25.455844494, 27.4524015179, 29.4489630909, 31.445529535, 33.4421011704 };
		float weight[18] = { 0.033245, 0.0659162217, 0.0636705814, 0.0598194658, 0.0546642566, 0.0485871646, 0.0420045997, 0.0353207015, 0.0288880982, 0.0229808311, 0.0177815511, 0.013382297, 0.0097960001, 0.0069746748, 0.0048301008, 0.0032534598, 0.0021315311, 0.0013582974 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 18; ++i)
		{
			color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * ReShade::PixelSize.y) * GaussianBlurOffset).rgb * weight[i];
		}
	}

	float3 orig = tex2D(ReShade::BackBuffer, texcoord).rgb;
	orig = lerp(orig, color, GaussianBlurStrength);

	return saturate(orig);
}

float3 GaussianBlur1(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	// Get color from the back buffer
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	if (bUIDisableDisplayDepth) {
		return color;
	}

	// Only blur the right side. If this is the left side, just return the current color and skip all processing.
	if (pos.x <= (BUFFER_WIDTH * 0.5)) { return color; }
	
	if(GaussianBlurRadius == 0)	
	{
		float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
		float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 4; ++i)
		{
			color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		}
	}	

	if(GaussianBlurRadius == 1)	
	{
		float offset[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
		float weight[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 6; ++i)
		{
			color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		}
	}	

	if(GaussianBlurRadius == 2)	
	{
		float offset[11] = { 0.0, 1.4895848401, 3.4757135714, 5.4618796741, 7.4481042327, 9.4344079746, 11.420811147, 13.4073334, 15.3939936778, 17.3808101174, 19.3677999584 };
		float weight[11] = { 0.06649, 0.1284697563, 0.111918249, 0.0873132676, 0.0610011113, 0.0381655709, 0.0213835661, 0.0107290241, 0.0048206869, 0.0019396469, 0.0006988718 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 11; ++i)
		{
			color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		}
	}	

	if(GaussianBlurRadius == 3)	
	{
		float offset[15] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4401038149, 21.43402885, 23.4279736431, 25.4219399344, 27.4159294386 };
		float weight[15] = { 0.0443266667, 0.0872994708, 0.0820892038, 0.0734818355, 0.0626171681, 0.0507956191, 0.0392263968, 0.0288369812, 0.0201808877, 0.0134446557, 0.0085266392, 0.0051478359, 0.0029586248, 0.0016187257, 0.0008430913 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 15; ++i)
		{
			color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		}
	}	

	if(GaussianBlurRadius == 4)	
	{
		float offset[18] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4661974725, 21.4627427973, 23.4592916956, 25.455844494, 27.4524015179, 29.4489630909, 31.445529535, 33.4421011704 };
		float weight[18] = { 0.033245, 0.0659162217, 0.0636705814, 0.0598194658, 0.0546642566, 0.0485871646, 0.0420045997, 0.0353207015, 0.0288880982, 0.0229808311, 0.0177815511, 0.013382297, 0.0097960001, 0.0069746748, 0.0048301008, 0.0032534598, 0.0021315311, 0.0013582974 };
		
		color *= weight[0];
		
		[unroll]
		for(int i = 1; i < 18; ++i)
		{
			color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
			color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * ReShade::PixelSize.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		}
	}

	return saturate(color);
}

// -- Depth Functions --

// value at [begin, end)
// See also: https://qiita.com/yuichiroharai/items/6e378cd128279ac9a2f0 (Japanese)
float StepIsRange(float f, float t, float v)
{
	float b = min(f, t);
	float e = max(f, t);
	return (step(b, v) - step(e, v));
}

// See: https://qiita.com/oishihiroaki/items/9d899cdcb9bee682531a (Japanese)
float Bias(float b, float x)
{
	return pow(x, log(b) / log(0.5));
}

// See: https://qiita.com/oishihiroaki/items/9d899cdcb9bee682531a (Japansese)
//! @param[in] gain Gain factor: [0.0, 1.0], 0.0 is "retval = x".
//! @return float translated value.
float InvertedGain(float gain, float x)
{
	float g = lerp(0.5, 1.0, gain);
	return step(0.5, x) * (1.0 - Bias(1.0 - g, 2.0 - 2.0 * x) / 2.0)
	+ StepIsRange(0.0, 0.5, x) * (Bias(1.0 - g, 2.0 * x) / 2.0)
	+ (1.0 - step(x, 0.0)) * 0.0;
}


float GetConvertedDepth(float2 texcoord)
{
	float depth = ReShade::GetLinearizedDepth(texcoord);

	if (bUIIsUseClip) {
		if (iUIClipType == 0) {
			depth = ((clamp(depth, fNearClip, fFarClip) - fNearClip) * (1.0 / abs(fFarClip - fNearClip))) * step(fNearClip, fFarClip);
		} else if (iUIClipType == 1) {
			depth = smoothstep(fNearClip, fFarClip, depth);
		} /* else {
			depth = depth;
		} */
	}

	/*
	depth = IsRange(0.0, fUIFarFactor, depth) * depth * 0.5 / fUIFarFactor
	+ IsRange(fUIFarFactor, 1.0, depth) * ((depth - fUIFarFactor) * 0.5 / (1.0 - fUIFarFactor) + 0.5)
	+ step(1.0, depth) * depth;
	*/
	depth = saturate(depth);

	return depth;
}

// See: https://stackoverflow.com/questions/14212984/custom-depth-shader-from-grayscale-to-rgba
float3 DepthToRGB(in float depth)
{
	float3 color;

	float d = saturate(depth);

	// RED
	float dr = d / 0.9;
	color.r = StepIsRange(0.0, 0.75, dr) * (-2.13 * pow(dr, 4.0) - 1.07 * pow(dr, 3.0) + 0.133 * pow(dr, 2.0) + 0.0667 * dr + 1.0);

	// GREEN
	color.g = (1.0 - step(d, 0.5)) * (1.6 * pow(d, 2) + 1.2 * d) + step(0.5, d) * (3.2 * pow(d, 2) - 6.8 * d + 3.6);

	// BLUE
	color.b = (1.0 - step(d, 0.5)) * (-4.8 * pow(d, 2) + 9.2 * d - 3.4);

	color = saturate(color);
	return color;
}

void PS_CalculateConvertedDepth(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float color : SV_Target)
{
	color = GetConvertedDepth(texcoord);
}

void PS_CalculateModefiedDepth(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float2 fragment : SV_Target)
{
	float2 focuscoord = float2(BUFFER_RCP_WIDTH * iAutoFocusTargetX, BUFFER_RCP_HEIGHT * iAutoFocusTargetY);
	float currdepth = tex2D(ConvertedDepthSampler, focuscoord).r;
	float2 preval = tex2Dfetch(PreviousModifiedDepthS, int2(0, 0));
	float2 nextval = float2(preval.r, preval.g);
	if (!bUIIsUseAutoFocus) {
		fragment = nextval;
		return;
	}
	if (fTimer > (preval.g + fAutoFocusGraceDuration))  {
		float currdiff = fAutoFocusTargetDepth - currdepth;
		float nextdepth = abs(currdiff) > fAutoFocusPermissiveWidth ? fAutoFocusTargetDepth : currdepth;
		nextval = float2(nextdepth, fTimer);
	}
	fragment = nextval;
}

void PS_StoreCurrentModifiedDepth(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float2 fragment : SV_Target)
{
	fragment = tex2Dfetch(CurrentModifiedDepthS, int2(0,0)).rg;
}

void PS_DebugView_Pre(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float4 fragment : SV_Target)
{
	fragment = float4(0, 0, 0, 0);

	if (bDebugFlag) {
		float depth = saturate(tex2D(ConvertedDepthSampler, texcoord).r);
		fragment = depth <= 0.0 ? DEBUG_NEAR_CLIP_COLOR : (depth >= 1.0 ? DEBUG_FAR_CLIP_COLOR : fragment);
		if (bUIIsUseAutoFocus) {
			float2 focuscoord = float2(BUFFER_RCP_WIDTH * iAutoFocusTargetX, BUFFER_RCP_HEIGHT * iAutoFocusTargetY);
			float2 offsetdepth = tex2Dfetch(CurrentModifiedDepthS, int2(0, 0));
			float2 focusdepth = tex2D(ConvertedDepthSampler, focuscoord).r;
			float2 modifieddepth = tex2Dfetch(PreviousModifiedDepthS, int2(0, 0)).r;
			fragment = abs(focusdepth - depth) <= fAutoFocusPermissiveWidth ? DEBUG_FOCUS_PLANE_COLOR : fragment;
		}
	}

	if ((bUIIsUseAutoFocus && (bUIShowFocusPoint || bDebugFlag))) {
		float2 focuscoord = float2(BUFFER_RCP_WIDTH * iAutoFocusTargetX, BUFFER_RCP_HEIGHT * iAutoFocusTargetY);
		float2 diff = abs(texcoord - focuscoord);
		float4 drawcolor = fTimer > (tex2D(PreviousModifiedDepthS, float2(0, 0)).y + fAutoFocusGraceDuration) ? FOCUS_POINT_RUNNING_COLOR : FOCUS_POINT_STOPPED_COLOR;
		fragment = (diff.x < FOCUS_POINT_HALFSIZE.x) && (diff.y < FOCUS_POINT_HALFSIZE.y) ? drawcolor : fragment;
	}


}

// -- LKG Functions --

void CenterView(inout float4 position : SV_Position, inout float2 texcoord : TEXCOORD, out float half_buffer)
{
	// Calculate half and quarter buffer width
	half_buffer = BUFFER_WIDTH * 0.5;
	float quarter_buffer = half_buffer * 0.5;
	
	// Force to use the left side of the view only
	if (position.x <= half_buffer)
	{
		position.x = position.x + (quarter_buffer * (XOffset + 1.0));
		texcoord.x = texcoord.x + (0.25 * (XOffset + 1.0));
	}
	else
	{
		position.x = (position.x - half_buffer) + (quarter_buffer * (XOffset + 1.0));
		texcoord.x = (texcoord.x - 0.5) + (0.25 * (XOffset + 1.0));
	}
}

void PS_LKGPortrait(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	if (bUIDisableDisplayDepth) {
		color = tex2D(ReShade::BackBuffer, texcoord).rgb;
		return;
	}

	// Save the original x
	float original_x = position.x;

	// Place to recieve half buffer
	float half_buffer = 0;
	
	// Center the viewport
	CenterView(position, texcoord, half_buffer);

	float depth = bUIIsUseAutoFocus ? saturate(tex2D(ConvertedDepthSampler, texcoord).r + ( tex2D(ConvertedDepthSampler, float2(0,0)).r - tex2Dfetch(CurrentModifiedDepthS, int2(0,0)).r) ) : tex2D(ConvertedDepthSampler, texcoord).r;

	depth = Bias(1.0 - fUIGammaFactor, depth);

	float3 colored_depth = 0.0;
#if REGLASS_OUTPUT_IS_CHROMA
	colored_depth = DepthToRGB(depth);
#else
	colored_depth = 1.0 - depth.xxx; // Invert since LookingGlass wants white as close
#endif

	// Ordered dithering
#if 1
	const float dither_bit = 8.0; // Number of bits per channel. Should be 8 for most monitors.
	// Calculate grid position
	float grid_position = frac(dot(texcoord, (BUFFER_SCREEN_SIZE * float2(1.0 / 16.0, 10.0 / 36.0)) + 0.25));
	// Calculate how big the shift should be
	float dither_shift = 0.25 * (1.0 / (pow(2, dither_bit) - 1.0));
	// Shift the individual colors differently, thus making it even harder to see the dithering pattern
	float3 dither_shift_RGB = float3(dither_shift, -dither_shift, dither_shift); // Subpixel dithering
	// Modify shift acording to grid position.
	dither_shift_RGB = lerp(2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position);
	colored_depth += dither_shift_RGB;
#endif

	// Get the original color at this position
	float3 color_orig = tex2D(ReShade::BackBuffer, texcoord).rgb;

	// Show split color and depth
	color = lerp(color_orig, colored_depth, step(half_buffer, original_x));
}

technique LookingGlass <
	ui_tooltip = "This shader allows you to capture screenshots in the right format for Looking Glass Portrait.\n"
	             "Global depth settings are intentionally overwritten while this shader is active.\n";
>

{

	pass ConvertDepth
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CalculateConvertedDepth;
		RenderTarget = ConvertedDepthTex;
	}
	pass CalcOffset
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CalculateModefiedDepth;
		RenderTarget = CurrentModifiedDepthT;
	}
	pass StoreCurrent
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_StoreCurrentModifiedDepth;
		RenderTarget = PreviousModifiedDepthT;
	}
	pass DebugViewPre
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_DebugView_Pre;
		ClearRenderTargets = false;
		BlendEnable = true;
		SrcBlend = SRCALPHA;
		SrcBlendAlpha = SRCALPHA;
		DestBlend = INVSRCALPHA;
		DestBlendAlpha = INVSRCALPHA;
	}
	pass LKG
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LKGPortrait;
	}
	pass Blur1
	{
		VertexShader = PostProcessVS;
		PixelShader = GaussianBlur1;
		RenderTarget = GaussianBlurTex;
	}
	pass BlurFinal
	{
		VertexShader = PostProcessVS;
		PixelShader = GaussianBlurFinal;
	}
}
