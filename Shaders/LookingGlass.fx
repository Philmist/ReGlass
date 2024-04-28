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
		#define DEPTH_OUTPUT_CHROMA_TEXT "REGLASS_OUTPUT_IS_CHROMA = 1"
	#else
		#define DEPTH_OUTPUT_CHROMA_TEXT "REGLASS_OUTPUT_IS_CHROMA = 0"
	#endif

	uniform int LG_about <
		ui_type = "radio"; ui_label = " ";
		ui_text =
			"These settings configure how your screen should appear when taking screenshots for Looking Glass.\n"
			"\n"
			"\n"
			"Using the sliders below, try to achieve a full range of bright white to grey to black. When ready,\n"
			"make sure to use ReShade to take the screenshot and not the game itself.\n";
	>;

	uniform int LG_help <
		ui_category = "Additional Info"; 
		ui_category_closed = true;		
		ui_type = "radio"; ui_label = " ";
		ui_text =
			"The settings below are only used while this filter is active, but some global settings will affect.\n"
			"how screenshots appear. For example:\n"
			"\n"
			DEPTH_OUTPUT_CHROMA_TEXT "\n";
	>;	
#endif

// -- Options --

/*
uniform float fUIFarPlane <
	ui_type = "drag";
	ui_label = "Far Importance";
	ui_tooltip = "How much importance is given to objects that are far away.\n";
	ui_min = 0.0; ui_max = 1000.0;
	ui_step = 0.1;
> = 1000.0;

uniform float fUIDepthMultiplier <
	ui_type = "drag";
	ui_label = "Multiplier";
	ui_tooltip = "RESHADE_DEPTH_MULTIPLIER=<value>";
	ui_min = 0.0; ui_max = 1000.0;
	ui_step = 0.001;
> = 1.0;
*/

uniform float fUIFarFactor <
	ui_type = "drag";
	ui_label = "Far factor";
	ui_tooltip = "A value that is used where should be more important.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

// Caution: 0.0 is less emphasize.
uniform float fUIGainFactor <
	ui_type = "drag";
	ui_label = "Gain factor";
	ui_tooltip = "A gradient factor to emphasize depth value.";
	ui_step = 0.01;
	ui_min = 0.0; ui_max = 1.0;
> = 0.0;

uniform int iUIIsUseClip <
	ui_type = "combo";
	ui_label = "Enable far/near clip";
	ui_items = "Off\0On(simple)\0ON(smoothstep)\0";
> = 0;

uniform float fNearClip <
	ui_type = "drag";
	ui_label = "Near clip position";
	ui_tooltip = "If original depth value is less than this, it will clamp at 0.0.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.0005;
> = 0.0;

uniform float fFarClip <
	ui_type = "drag";
	ui_label = "Far clip position";
	ui_tooltip = "If original depth value is greater than this, it will clamp at 1.0.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.0005;
> = 1.0;

uniform int GaussianBlurRadius <
	ui_type = "drag";
	ui_label = "Blur Radius";
	ui_tooltip = "How many neighboring pixels influence the original pixel.";
	ui_min = 0.0; ui_max = 4.0;
	ui_step = 1.0;
> = 4;

uniform float GaussianBlurStrength <
	ui_type = "drag";
	ui_label = "Blur Strength";
	ui_tooltip = "How strongly do neighboring pixels influence the original pixel.";
	ui_min = 0.00; ui_max = 1.00;
	ui_step = 0.001;
> = 1.000;

uniform float GaussianBlurOffset <
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

// -- Variables --

texture GaussianBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler GaussianBlurSampler { Texture = GaussianBlurTex;};

// -- Blur Functions --

float3 GaussianBlurFinal(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	// Get color from the sampler
	float3 color = tex2D(GaussianBlurSampler, texcoord).rgb;

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
float IsRange(float b, float e, float v)
{
	float from = step(b, v);
	float end = 1.0 - step(e, v);
	return from * end;
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
	float g = lerp(0.5, 0.99999, gain);
	return IsRange(0.5, 1.0, x) * (1.0 - Bias(1.0 - g, 2.0 - 2.0 * x) / 2.0)
	+ IsRange(0.0, 0.5, x) * (Bias(1.0 - g, 2.0 * x) / 2.0);
}


float GetConvertedDepth(float2 texcoord)
{
	/*
	if (RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN)
		texcoord.y = 1.0 - texcoord.y;

	float depth = tex2Dlod(ReShade::DepthBuffer, float4(texcoord, 0, 0)).x;
	depth = depth * fUIDepthMultiplier;

	const float C = 0.01;
	if (RESHADE_DEPTH_INPUT_IS_LOGARITHMIC)
		depth = (exp(depth * log(C + 1.0)) - 1.0) / C;

	if (RESHADE_DEPTH_INPUT_IS_REVERSED)
		depth = 1.0 - depth;
	*/

	float depth = ReShade::GetLinearizedDepth(texcoord);

	if (iUIIsUseClip == 1) {
		depth = ((clamp(depth, fNearClip, fFarClip) - fNearClip) * (1.0f / abs(fFarClip - fNearClip))) * step(fNearClip, fFarClip);
	} else if (iUIIsUseClip == 2) {
		depth = smoothstep(fNearClip, fFarClip, depth);
	} /* else {
		depth = depth;
	} */

	//depth = InvertedGain(fUIGainFactor, Bias(1.0 - fUIFarFactor, depth));
	depth = IsRange(0.0, fUIFarFactor, depth) * depth * 0.5 / fUIFarFactor
	+ IsRange(fUIFarFactor, 1.01, depth) * ((depth - fUIFarFactor) * 0.5 / (1.0 - fUIFarFactor) + 0.5);
	//depth = IsRange(0.0, 1.0, depth) * depth;

	depth = InvertedGain(fUIGainFactor, depth);

	/*
	const float N = 1.0;
	depth /= fUIFarPlane - depth * (fUIFarPlane - N);
	*/
	// const float fMaxDepth = (1.0 * fUIDepthMultiplier) / (fUIFarPlane - 1.0 * fUIDepthMultiplier * (fUIFarPlane - N));
	// depth /= (step(1.0f, fMaxDepth) * (fMaxDepth - 1.0f)) + 1.0f;  // fit to [0.0, 1.0]
	depth = saturate(depth);

	return depth;
}

// See: https://stackoverflow.com/questions/14212984/custom-depth-shader-from-grayscale-to-rgba
float3 DepthToRGB(in float d)
{
	float3 color;

	// RED
	color.r = d * 0.9f;
	color.r = IsRange(0f, 0.75f, color.r) * (-2.13f * pow(color.r, 4) - 1.07f * pow(color.r, 3) + 0.133f * pow(color.r, 2) + 0.0667 * color.r + 1f);

	// GREEN
	color.g = IsRange(0f, 0.5f, d) * (1.6f * pow(d, 2) + 1.2f * d) + step(0.5f, d) * (3.2f * pow(d, 2) - 6.8f * d + 3.6f);

	// BLUE
	color.b = (1.0f - step(d, 0.5f)) * (-4.8f * pow(d, 2) + 9.2f * d - 3.4f);

	color = saturate(color);
	return color;
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
		position.x = position.x + (quarter_buffer * (XOffset + 1));
		texcoord.x = texcoord.x + (0.25 * (XOffset + 1));
	}
	else
	{
		position.x = (position.x - half_buffer) + (quarter_buffer * (XOffset + 1));
		texcoord.x = (texcoord.x - 0.5) + (0.25 * (XOffset + 1));
	}
}

void PS_LKGPortrait(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	// Save the original x
	float original_x = position.x;

	// Place to recieve half buffer
	float half_buffer = 0;
	
	// Center the viewport
	CenterView(position, texcoord, half_buffer);

	// Calculate depth and normal
	float3 depth = 0.0f;
#if REGLASS_OUTPUT_IS_CHROMA
	depth = DepthToRGB(1.0f - GetConvertedDepth(texcoord).xxx);
#else
	depth = 1.0 - GetConvertedDepth(texcoord).xxx; // Invert since LookingGlass wants white as close
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
	depth += dither_shift_RGB;
#endif

	// Get the original color at this position
	float3 color_orig = tex2D(ReShade::BackBuffer, texcoord).rgb;

	// Show split color and depth
	color = lerp(color_orig, depth, step(half_buffer, original_x));
}

technique LookingGlass <
	ui_tooltip = "This shader allows you to capture screenshots in the right format for Looking Glass Portrait.\n"
	             "Global depth settings are intentionally overwritten while this shader is active.\n";
>

{

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
