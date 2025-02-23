
open Render.Program;


module type Programs = sig
  module Normal: sig
    value id: id;
    value create: unit -> Render.prg;
  end;
  module ColorMatrix: sig
    value id: id;
    value create: Render.filter -> Render.prg;
  end;
  module Stroke: sig
    value id: id;
    value create: Render.filter -> Render.prg;
  end;
(*   module StrokeWithColorMatrix: sig
    value id: id;
    value create: ~matrix:(array float) -> ~stroke:int -> unit -> Render.prg;
  end;   *)
end;

module Shape =
  struct
    value id = gen_id ();
    value create () =
      let prg = 
        load id ~vertex:"Shape.vsh" ~fragment:"Shape.fsh" 
          ~attributes:[ (Render.Program.AttribPosition,"a_position") ] 
          ~uniforms:[| ("u_color", UNone); ("u_alpha", UNone) |]
      in
        (prg,None);
  end;

module Shadow =
  struct
    value id = gen_id ();
    value create () =
      let prg =
        load id ~vertex:"ShadowFirstPass.vsh" ~fragment:"ShadowFirstPass.fsh"
          ~attributes:[ (Render.Program.AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord") ]
          ~uniforms:[| ("u_texture",(UInt 0)); ("u_radius", UNone); ("u_color", UNone); ("u_height", UNone) |]
      in
        (prg, None);
  end;

module Quad = struct

  module Normal = struct
    value id = gen_id();
    value create () = 
      let prg = 
        load id ~vertex:"Quad.vsh" ~fragment:"Quad.fsh" 
          ~attributes:[ (Render.Program.AttribPosition,"a_position"); (Render.Program.AttribColor,"a_color") ] 
          ~uniforms:[| |]
      in
      (prg,None);
  end;


  module ColorMatrix = struct
    value id = gen_id();
    value create () = assert False;
  end;

  module Stroke = struct
    value id = gen_id();
    value create stroke = assert False;
  end;


end;

module Image = struct (*{{{*)


  module Normal = struct

    value id = gen_id ();
    value cache : ref (option Render.prg) = ref None;

  (*
  value clear_cache () = cache.val := None;
  Callback.register "image_program_cache_clear" clear_cache;
  *)

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
  end;


  module ColorMatrix = struct
    value id  = gen_id();
    value create matrix = 
      let prg = 
        load id ~vertex:"Image.vsh" ~fragment:"ImageColorMatrix.fsh"
          ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
          ~uniforms:[| ("u_texture", (UInt 0)); ("u_matrix",UNone) |]
      in
      (prg,Some matrix);
  end;

  module Stroke = struct
    value id = gen_id();
    value create stroke = assert False;
  end;

(*   module StrokeWithColorMatrix = struct
    value id = gen_id();
    value create ~matrix ~stroke () = assert False;
  end; *)
end;(*}}}*)

module ImagePallete = struct (*{{{*)

  module Normal = struct
    value id = gen_id ();
    value create () = 
      let prg = 
        load id ~vertex:"Image.vsh" ~fragment:"ImagePallete.fsh"
          ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
          ~uniforms:[| ("u_texture",(UInt 0)) ; ("u_pallete",(UInt 1)) |]
      in
      (prg,None);
  end;

  module ColorMatrix = struct
    value id  = gen_id();
    value create matrix = 
      let prg = 
        load id ~vertex:"Image.vsh" ~fragment:"ImagePalleteColorMatrix.fsh"
          ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
          ~uniforms:[| ("u_texture", (UInt 0));  ("u_matrix",UNone) ; ("u_pallete",(UInt 1)) |]
      in
      (prg,Some matrix);
  end;

  module Stroke = struct
    value id = gen_id();
    value create stroke = assert False;
  end;

(*   module StrokeWithColorMatrix = struct
    value id = gen_id();
    value create ~matrix ~stroke () = assert False;
  end; *)

end;(*}}}*)

module ImageAlpha = struct (*{{{*)


  module Normal = struct
    value id = gen_id ();
    value create () = 
      let prg = 
        load id ~vertex:"Image.vsh" ~fragment:"ImageAlpha.fsh"
          ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
          ~uniforms:[| ("u_texture",(UInt 0)) |]
      in
      (prg,None);
  end;

  module ColorMatrix = struct
    value id  = gen_id();
    value create matrix = 
      let prg = 
        load id ~vertex:"Image.vsh" ~fragment:"ImageAlphaColorMatrix.fsh"
          ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
          ~uniforms:[| ("u_texture", (UInt 0)); ("u_matrix",UNone) |]
      in
      (prg,Some matrix);
  end;

  module Stroke = struct
    value id = gen_id ();
    value create stroke = Normal.create ();
  end;


(*   module StrokeWithColorMatrix = struct
    value id = gen_id ();
    value create ~matrix ~stroke () = ColorMatrix.create (Filters._colorMatrix matrix);
  end; *)
end;(*}}}*)

module ImageCmprsWithAlpha = struct (*{{{*)

  module Normal = struct
    value id = gen_id ();
    value create () = 
      let prg = 
        load id ~vertex:"Image.vsh" ~fragment:"ImageEtcWithAlpha.fsh"
          ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
          ~uniforms:[| ("u_texture",(UInt 0)) ; ("u_alpha",(UInt 1)) |]
      in
        (prg,None);
  end;

  module ColorMatrix = struct
    value id  = gen_id();
    value create matrix = 
      let prg = 
        load id ~vertex:"Image.vsh" ~fragment:"ImageEtcWithAlphaColorMatrix.fsh"
          ~attributes:[ (AttribPosition,"a_position");  (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color") ]
          ~uniforms:[| ("u_texture", (UInt 0));  ("u_matrix",UNone) ; ("u_alpha",(UInt 1)) |]
      in
      (prg,Some matrix);
  end;

  module Stroke = struct
    value id = gen_id();
    value create stroke = assert False;
  end;

(*   module StrokeWithColorMatrix = struct
    value id = gen_id ();
    value create ~matrix ~stroke () = assert False;
  end; *)
end; (*}}}*)

module TlfAtlas =
  struct
    module Normal = ImageAlpha.Normal;

    module ColorMatrix = ImageAlpha.ColorMatrix;

    module Stroke = struct
      value id = gen_id();
      value create stroke =
        let prg = 
          load id ~vertex:"Image.vsh" ~fragment:"StrokedTlf.fsh"
            ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
            ~uniforms:[| ("u_texture",(UInt 0)); ("u_strokeColor", (UNone)) |]
        in
          (prg, Some stroke);
    end;

(*     module StrokeWithColorMatrix = struct
      value id = gen_id ();
      value create ~matrix ~stroke () =
        let prg = 
          load id ~vertex:"Image.vsh" ~fragment:"StrokedTlfWithColorMatrix.fsh"
            ~attributes:[ (AttribPosition,"a_position"); (AttribTexCoords,"a_texCoord"); (AttribColor,"a_color")  ]
            ~uniforms:[| ("u_texture",(UInt 0)); ("u_strokeColor", (UNone)); ("u_matrix",UNone) |]
        in
          (prg, Some (Filters.strokeWithColorMatrix (stroke land 0x00ffffff lor 0xff000000) matrix));
    end; *)
  end;


value select_by_texture = fun
  [ Texture.Simple _ -> (module Image:Programs)
  | Texture.Alpha -> (module ImageAlpha:Programs)
  | Texture.Pallete _ -> (module ImagePallete:Programs)
  | Texture.CmprsWithAlpha _ -> (module ImageCmprsWithAlpha:Programs)
  | Texture.LuminanceAlpha -> (module TlfAtlas:Programs)
  ];
