
open Render.Program;

module Quad = struct
  value id = gen_id();
  value create () = 
    let prg = 
      load id ~vertex:"Quad.vsh" ~fragment:"Quad.fsh" 
        ~attributes:[ (Render.Program.AttribPosition,"a_position"); (Render.Program.AttribColor,"a_color") ] 
        ~uniforms:[| |]
    in
    (prg,None);

end;

module Image = struct (*{{{*)

  value id = gen_id ();
  value cache : ref (option Render.prg) = ref None;
  value clear_cache () = cache.val := None;
  Callback.register "image_program_cache_clear" clear_cache;

  value create () = 
    match !cache with
    [ None ->
      let res = 
        let prg = 
          load id ~vertex:"Image.vsh" ~fragment:"Image.fsh"
            ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
            ~uniforms:[| ("u_texture",(UInt 0)) |]
        in
        (prg,None)
      in
      (
        cache.val := Some res;
        res
      )
    | Some res -> res
    ];

end;(*}}}*)

module ImagePallete = struct (*{{{*)
  value id = gen_id ();
  value create () = 
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImagePallete.fsh"
        ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
        ~uniforms:[| ("u_texture",(UInt 0)) ; ("u_pallete",(UInt 1)) |]
    in
    (prg,None);

end;(*}}}*)

module ImageAlpha = struct (*{{{*)
  value id = gen_id ();
  value create () = 
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImageAlpha.fsh"
        ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
        ~uniforms:[| ("u_texture",(UInt 0)) |]
    in
    (prg,None);

end;(*}}}*)

module ImageColorMatrix = struct (*{{{*)

  value id  = gen_id();
  value create matrix = 
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImageColorMatrix.fsh"
        ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
        ~uniforms:[| ("u_texture", (UInt 0)); ("u_matrix",UNone) |]
    in
    (prg,Some matrix);
(*
    let f = Render.Filter.color_matrix matrix in
    (prg,Some f);
*)
    
(*
  value from_filter filter =
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImageColorMatrix.fsh"
        ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
        ~uniforms:[| ("u_texture", (UInt 0)); ("u_matrix",UNone) |]
    in
    (prg,Some filter);
*)

end;(*}}}*)

module ImagePalleteColorMatrix = struct (*{{{*)

  value id  = gen_id();
  value create matrix = 
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImagePalleteColorMatrix.fsh"
        ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
        ~uniforms:[| ("u_texture", (UInt 0));  ("u_matrix",UNone) ; ("u_pallete",(UInt 1)) |]
    in
    (prg,Some matrix);

  (*
  value from_filter filter =
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImagePalleteColorMatrix.fsh"
        ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
        ~uniforms:[| ("u_texture", (UInt 0));  ("u_matrix",UNone) ; ("u_pallete",(UInt 1)) |]
    in
    (prg,Some filter);
  *)
    
end;(*}}}*)

module ImageAlphaColorMatrix = struct (*{{{*)

  value id  = gen_id();
  value create matrix = 
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImageAlphaColorMatrix.fsh"
        ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
        ~uniforms:[| ("u_texture", (UInt 0)); ("u_matrix",UNone) |]
    in
    (prg,Some matrix);
    
  (*
  value from_filter filter =
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImageAlphaColorMatrix.fsh"
        ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
        ~uniforms:[| ("u_texture", (UInt 0)); ("u_matrix",UNone) |]
    in
    (prg,Some filter);
  *)

end;(*}}}*)

module ImageEtcWithAlpha = struct
  value id = gen_id ();
  value create () = 
    let prg = 
      load id ~vertex:"Image.vsh" ~fragment:"ImageEtcWithAlpha.fsh"
        ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
        ~uniforms:[| ("u_texture",(UInt 0)) ; ("u_alpha",(UInt 1)) |]
    in
      (prg,None);
end;