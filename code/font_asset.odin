package main
import os  "core:os"
import fmt "core:fmt"
import win32 "core:sys/windows"

ImageHeader::struct #packed{
	width             : u32,
	height            : u32,
	pitch             : u32,
	width_over_height : f32,
}

GlyphHeader::struct #packed{
	code_point   :rune,
	advance      :f32,
	left_bearing :f32,
	x_offset     :f32,
	y_offset     :f32,
	min_uv       :v2_f32,
	max_uv       :v2_f32,
}

FontHeader::struct #packed{
	kerning_pairs  :f32,
	ascent         :f32,
	descent        :f32,
	line_gap       :f32,
	line_advance   :f32,
	size           :u32
}

//Don't use this use LoadedBitmap
Image::struct #packed{
	width             : u32,
	height            : u32,
	pitch             : u32,
	width_over_height : f32,
	pixels            : ^u32,
}

Glyph::struct #packed{
	code_point   :rune,
	advance      :f32,
	left_bearing :f32,
	x_offset     :f32,
	y_offset     :f32,
	min_uv       :v2_f32,
	max_uv       :v2_f32,
	image        :LoadedBitmap,
}

Font::struct #packed{
	kerning_pairs  :f32,
	ascent         :f32,
	descent        :f32,
	line_gap       :f32,
	line_advance   :f32,
	size           :u32
	glyphs         :[128]Glyph,
}
F_ONE_OVER_255::0.00392156862



read_font_asset::proc(font_file:string, font:^Font){
	using os

	font:=font

	asset_file, status :=  read_entire_file_from_filename(font_file)
	if(!status){
		fmt.println("Failed to read file")
	}

	font_header :=  cast(^FontHeader)rawptr(&asset_file[0])

	font.kerning_pairs  = font_header.kerning_pairs
	font.ascent         = font_header.ascent
	font.descent        = font_header.descent
	font.line_gap       = font_header.line_gap
	font.line_advance   = font_header.line_advance
	font.size           = font_header.size

	offset:u32= size_of(FontHeader);

	for i in 33..<128{
		assert(i <=128)
		
		c:=rune(i)

		glyph:Glyph = {}

		glyph_header := cast(^GlyphHeader)rawptr(uintptr(&asset_file[0]) + uintptr(offset))
		glyph.code_point   =glyph_header.code_point
		glyph.advance      =glyph_header.advance
		glyph.left_bearing =glyph_header.left_bearing
		glyph.x_offset     =glyph_header.x_offset
		glyph.y_offset     =glyph_header.y_offset
		glyph.min_uv       =glyph_header.min_uv
		glyph.max_uv       =glyph_header.max_uv

		offset += size_of(GlyphHeader)

		image_header := cast(^ImageHeader)rawptr(uintptr(&asset_file[0]) + uintptr(offset))

		glyph.image.width             = i32(image_header.width)
		glyph.image.height            = i32(image_header.height)
		glyph.image.pitch             = i32(image_header.pitch)
		glyph.image.width_over_height = image_header.width_over_height

		offset += size_of(ImageHeader)
		glyph.image.pixels = cast(^u8)rawptr(uintptr(&asset_file[0]) + uintptr(offset))

		offset += image_header.pitch * image_header.height

		font.glyphs[i] = glyph
	}
}





















