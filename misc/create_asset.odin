package misc

import "core:os"
import "core:mem"
import "core:fmt"
import win32  "core:sys/windows"
import libc   "core:c/libc"
import        "core:intrinsics"
import stb_tt "vendor:stb/truetype"

const_utf16 :: intrinsics.constant_utf16_cstring

v2_f32::[2]f32
v4::struct{r,g,b,a:f32}

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
    size           :u32,
}

Image::struct #packed{
    width             : u32,
    height            : u32,
    pitch             : u32,
    width_over_height : f32,
    pixels            : ^u8,
}

Glyph::struct #packed{
    code_point   :rune,
    advance      :f32,
    left_bearing :f32,
    x_offset     :f32,
    y_offset     :f32,
    min_uv       :v2_f32,
    max_uv       :v2_f32,
    image        :Image,
}

Font::struct #packed{
    kerning_pairs  :f32,
    ascent         :f32,
    descent        :f32,
    line_gap       :f32,
    line_advance   :f32,
    size           :u32,
    glyphs         :[128]Glyph,
}


F_ONE_OVER_255::0.00392156862

// NOTE(Dima): Color math
PackRGBA::proc(Color:v4)->u32{
    Res:u32= 
	cast(u32)((Color.r * 255.0 + 0.5)) |
	(cast(u32)((Color.g * 255.0) + 0.5) << 8) |
	(cast(u32)((Color.b * 255.0) + 0.5) << 16) |
	(cast(u32)((Color.a * 255.0) + 0.5) << 24);
    
    return(Res);
}

UnpackRGBA::proc(Color:u32)->v4{
    Res:v4;
    
    Res.r = f32(Color & 0xFF) * F_ONE_OVER_255
    Res.g = f32((Color >> 8) & 0xFF) * F_ONE_OVER_255
    Res.b = f32((Color >> 16) & 0xFF) * F_ONE_OVER_255
    Res.a = f32((Color >> 24) & 0xFF) * F_ONE_OVER_255
    return(Res);
}

make_empty_image::proc(width:u32, height:u32)->Image{
    result:Image     = {}
    result.width     = width
    result.height    = height
    result.pitch     = width * 4 
    result.pixels    = cast(^u8)libc.calloc(uint(result.pitch * result.height), 1)
    result.width_over_height = f32(width)/f32(height)
    return result
}

create_font_asset::proc(size:u32, font_path:string, handle: os.Handle){
    result: Font = {}
    result.size = size

    font_file, status :=  os.read_entire_file_from_filename("c:/Windows/Fonts/Consola.ttf")

    if !status{
	fmt.println("Failed to read file")
	return
    }


    using stb_tt

    info:fontinfo

    if(!InitFont(&info, &font_file[0],0)){
	fmt.println("Failed")
    }

    scale := ScaleForPixelHeight(&info, f32(result.size))

    ascent, descent, line_gap:i32

    GetFontVMetrics(&info, &ascent, &descent, &line_gap)
    result.ascent    = f32(ascent)   * scale
    result.descent   = f32(descent)  * scale
    result.line_gap  = f32(line_gap) * scale

    result.line_advance = result.ascent - result.descent + result.line_gap

    for i in 33..<128{
	c:=rune(i)

	glyph:Glyph = {}

	advance, left_bearing :i32
	
	GetCodepointHMetrics(&info, c, &advance, &left_bearing)

	glyph.code_point = c
	glyph.advance = f32(advance) * scale
	glyph.left_bearing = f32(left_bearing)


	width, height, x_offset, y_offset :i32

	bitmap := GetCodepointBitmap(&info, 0, scale, c, &width, &height, &x_offset, &y_offset)

	if width > 200000{
	    width = 0
	}
	if height > 200000{
	    height = 0
	}

	border:i32=0
	glyph_width  :i32= width  + 2 * border
	glyph_height :i32= height + 2 * border

	glyph.image = make_empty_image(u32(glyph_width), u32(glyph_height))
	glyph.x_offset = f32(x_offset)
	glyph.y_offset = f32(y_offset)


	source : ^u8 = cast(^u8)bitmap
	offset :u32  = u32(glyph.image.height - 1) * u32(glyph.image.pitch)

	dest_row   : ^u8 = cast(^u8)(uintptr(glyph.image.pixels) + uintptr(offset))


	for y in 0..<glyph.image.height{
	    dest : ^u32 = cast(^u32)dest_row

	    for x:=int(glyph.image.width-1); x >= 0  ; x -=1{

		alpha:u8 = (cast(^u8)(rawptr(uintptr(source) + uintptr(x))))^

		alpha_u32 := u32(alpha)

		dest^ = alpha_u32 << 24 | alpha_u32 << 16 | alpha_u32 << 8 | alpha_u32 << 0
		dest  = cast(^u32)(uintptr(dest) + uintptr(size_of(u32)))

	    }
	    source = cast(^u8)(uintptr(source) + uintptr(glyph.image.width))
	    dest_row = cast(^u8)(uintptr(dest_row) - uintptr(glyph.image.pitch))
	}
	FreeBitmap(bitmap, rawptr(nil))
	result.glyphs[i] = glyph
    }


    font_header:=cast(^FontHeader)rawptr(&result)

    font_header_bytes := transmute([size_of(FontHeader)]u8)font_header^

    written,_ := os.write(handle, font_header_bytes[:])

    header_size := size_of(FontHeader)
    assert(written == header_size)


    for i in 33..<128{

	glyph := &result.glyphs[i]
	glyph_header := cast(^GlyphHeader)glyph


	glyph_header_bytes := transmute([size_of(GlyphHeader)]u8)glyph_header^
	    written,_ := os.write(handle, glyph_header_bytes[:])

	assert(written == size_of(GlyphHeader))

	image_header := cast(^ImageHeader)&glyph.image
	image_header_bytes := transmute([size_of(ImageHeader)]u8)image_header^
	    os.write(handle, image_header_bytes[:])

	pixel_size := glyph.image.pitch * glyph.image.height

	//os.write(handle, pixel_bytes[:])
	os.write_ptr(handle, rawptr(glyph.image.pixels), int(pixel_size))
    }

}

main::proc(){
    //Using this because i can't find a way to do it in os module 
    win_handle := win32.CreateFileW(const_utf16("../data/fonts.dat"), win32.GENERIC_READ|win32.GENERIC_WRITE, u32(0), cast(^win32.SECURITY_ATTRIBUTES)nil, win32.CREATE_ALWAYS, 0, nil);
  win32.CloseHandle(win_handle);

    file_name :string= "../data/fonts.dat"
    handle, err := os.open(file_name, os.O_APPEND)

    os.close(handle)
}
















