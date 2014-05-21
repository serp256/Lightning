open LightCommon;

exception Cant_load_texture of string;
Callback.register_exception "Cant_load_texture" (Cant_load_texture "");

type ubyte_array = Bigarray.Array1.t int Bigarray.int8_unsigned_elt Bigarray.c_layout;

type filter = [ FilterNearest | FilterLinear ];
value defaultFilter = ref FilterNearest;
value setDefaultFilter v = defaultFilter.val := v;

external glClear: int -> float -> unit = "ml_clear";
external set_texture_filter: textureID -> filter -> unit = "ml_texture_set_filter" "noalloc";
external zero_textureID: unit -> textureID = "ml_texture_id_zero";
external int32_of_textureID: textureID -> int32 = "ml_texture_id_to_int32";
external delete_textureID: textureID -> unit = "ml_texture_id_delete" "noalloc";
value string_of_textureID textureID = 
  let i = int32_of_textureID textureID in
  Int32.to_string i;

value scale = ref 1.;

(*  take care of accordance of this type and enum LTextureFormat from texture_common.h.
    rules to add new format:
      1) if new constructor has no params, put it at any place, but before first constructor with params
      2) if constuctor has params, put it at any place, but after last constructor without params
  *)
type textureFormat = 
  [ TextureFormatRGBA
  | TextureFormatRGB
  | TextureFormatAlpha
  | TextureFormatPvrtcRGB2
  | TextureFormatPvrtcRGBA2
  | TextureFormatPvrtcRGB4
  | TextureFormatPvrtcRGBA4
  | TextureFormat565
  | TextureFormat5551
  | TextureFormat4444  
  | TextureFormatDXT1
  | TextureFormatDXT5
  | TextureFormatATCRGB
  | TextureFormatATCRGBAE
  | TextureFormatATCRGBAI
  | TextureFormatETC1
  | TextureLuminance
  | TextureLuminanceAlpha  
  | TextureFormatPallete of int
  | TextureFormatETC1WithAlpha of textureInfo
  ]
and textureInfo = 
  {
    texFormat: textureFormat;
    realWidth: int;
    width: int;
    realHeight: int;
    height: int;
    pma:bool; 
    memSize: int;
    textureID: textureID;
  };

type kind = [ Simple of bool | Alpha | LuminanceAlpha | Pallete of textureInfo | EtcWithAlpha of textureInfo ];
type renderInfo =
  {
    rtextureID: textureID;
    rwidth: float;
    rheight: float;
    clipping: option Rectangle.t;
    kind: kind;
    rx: int;
    ry: int;
  };

class type renderer = 
  object
    method onTextureEvent: bool -> c -> unit;
  end
and c =
  object
    method kind : kind;
    method renderInfo: renderInfo;
    method scale: float;
    method width: float;
    method height: float;
    method hasPremultipliedAlpha:bool;
    method setFilter: filter -> unit;
    method textureID: textureID;
    method base : option c; 
    method clipping: option Rectangle.t;
    method rootClipping: option Rectangle.t;
    method released: bool;
    method release: unit -> unit;
    method subTexture: Rectangle.t -> c;
    method addRenderer: renderer -> unit;
    method removeRenderer: renderer -> unit;
  end;

  value zero_textureID = zero_textureID ();

value zero : c = 
  let renderInfo = { rtextureID = zero_textureID; rwidth = 0.; rheight = 0.; clipping = None; kind = Simple False; rx = 0; ry = 0 } in
  object(self)
    method kind = renderInfo.kind;
    method renderInfo = renderInfo;
    method width = 0.;
    method height = 0.;
    method scale = 1.;
    method hasPremultipliedAlpha = False;
    method setFilter filter = ();
(*     method scale = scale; *)
    method textureID = renderInfo.rtextureID;
    method base = None;
    method clipping = None;
    method rootClipping = None;
    method released = False;
    method release () = ();
    method subTexture _ = self;
    method addRenderer _ = ();
    method removeRenderer _ = ();
  end;

type imageInfo;
external loadImage: ?textureID:textureID -> ~path:string -> ~suffix:option string -> filter -> bool -> textureInfo = "ml_loadImage";


(* external loadImage: ?textureID:textureID -> ~path:string -> ~suffix:option string -> filter -> unit = "ml_loadImage"; 
value zero_textureInfo = 
  {
    texFormat= TextureFormatRGBA;
    realWidth= 0;
    width= 0;
    realHeight= 0;
    height= 0;
    pma=False; 
    memSize= 0;
    textureID = zero_textureID;
  };
value loadImage ?textureID ~path ~suffix filter =
  (
    loadImage ?textureID ~path ~suffix filter;
    zero_textureInfo;
  );
*)

module TextureCache = WeakHashtbl.Make (struct
  type t = string;
  value equal = (=);
  value hash = Hashtbl.hash;
end);



class subtexture region clipping ts (baseTexture:c) = 
  (*
  let ts = baseTexture#scale in
  let tw = baseTexture#width /. ts
  and th = baseTexture#height /. ts in
  *)
  let rootClipping = Rectangle.tm_of_t clipping in
  let () = 
    let open Rectangle in
    adjustClipping (baseTexture :> c) where
      rec adjustClipping texture =
        match texture#clipping with
        [ None -> ()
        | Some baseClipping ->
            (
              rootClipping.m_x := baseClipping.x +. rootClipping.m_x *. baseClipping.width;
              rootClipping.m_y := baseClipping.y +. rootClipping.m_y *. baseClipping.height;
              rootClipping.m_width := rootClipping.m_width *. baseClipping.width;
              rootClipping.m_height := rootClipping.m_height *. baseClipping.height;
              match texture#base with
              [ Some baseTexture -> adjustClipping baseTexture
              | None -> ()
              ]
            )
        ]
  in
  let renderInfo = 
    {
      rtextureID = baseTexture#textureID;
      rwidth = region.Rectangle.width *. ts; 
      rheight = region.Rectangle.height *. ts;
      clipping = Some (Obj.magic rootClipping);
      kind = baseTexture#kind;
      rx = 0;
      ry = 0;
    }
  in
  object(self)
    method renderInfo = renderInfo;
    method kind = renderInfo.kind;
    method width = renderInfo.rwidth;
    method height = renderInfo.rheight;
    method scale = baseTexture#scale;
    method textureID = renderInfo.rtextureID;
    method hasPremultipliedAlpha = baseTexture#hasPremultipliedAlpha;
(*     method scale = baseTexture#scale; *)
    method base = Some (baseTexture :> c);
    method clipping = Some clipping;
    method setFilter filter = set_texture_filter baseTexture#textureID filter;
    method rootClipping = renderInfo.clipping;
(*     method update path = baseTexture#update path; *)
    method subTexture region = 
      let scale = baseTexture#scale in
      let clipping = 
        let tw = renderInfo.rwidth /. scale
        and th = renderInfo.rheight /. scale in
        Rectangle.create 
          (region.Rectangle.x /. tw) 
          (region.Rectangle.y /. th) 
          (region.Rectangle.width /. tw) 
          (region.Rectangle.height /. th) 
      in
      ((new subtexture region clipping scale (self :> c)) :> c);
(*     method releaseSubTexture () = baseTexture#releaseSubTexture (); *)
    method released = baseTexture#released;
    method release () = ();(* let () = debug:gc "release subtexture" in baseTexture#releaseSubTexture (); *)
(*     method setTextureID tid = baseTexture#setTextureID tid; *)
    method addRenderer (_:renderer) = ();
    method removeRenderer (_:renderer) = ();
(*     initializer Gc.finalise (fun t -> t#release ()) self; *)
  end;

value cache = TextureCache.create 11;

value createSubtex region clipping ts baseTexture = ((new subtexture region clipping ts baseTexture) :> c);


(*
value texture_memory = ref 0;
value texture_mem_add v = 
  (
    texture_memory.val := !texture_memory + v;
    debug:mem "TextureMemory = %d" !texture_memory;
  );
value texture_mem_sub v = 
  (
    texture_memory.val := !texture_memory - v;
    debug:mem "TextureMemory = %d" !texture_memory;
  );
*)

(*
IFDEF ANDROID THEN
value reloadTextures () = 
  let () = debug:android "reload textures" in
  Cache.iter begin fun path t ->
    let textureInfo = loadImage path 1. in
    let textureID = GLTexture.create textureInfo in
    t#setTextureID textureID
  end;

Callback.register "realodTextures" reloadTextures;
ENDIF;
*)

(* external delete_texture: textureID -> unit = "ml_delete_texture"; *)

module PalleteCache = WeakHashtbl.Make(struct
  type t = int;
  value equal = (=);
  value hash = Hashtbl.hash;
end);

value palleteCache = PalleteCache.create 0;
value loadPallete palleteID = 
  try
    PalleteCache.find palleteCache palleteID
  with 
  [ Not_found ->
    let pallete = loadImage (Printf.sprintf "palletes/%d.plt" palleteID) None FilterNearest False in
    (
      PalleteCache.add palleteCache palleteID pallete;
      (* здесь бы финализер повесить на нее, но да хуй с ней нахуй *)
      pallete;
    )
  ];

module SubTextureCache = WeakHashtbl.Make(struct
  type t = Rectangle.t;
  value equal = (=);
  value hash = Hashtbl.hash;
end);

class s textureInfo = 
  let () = debug "make texture: <%ld>, width=[%d->%d],height=[%d -> %d]" (int32_of_textureID textureInfo.textureID) textureInfo.realWidth textureInfo.width textureInfo.realHeight textureInfo.height in
  let width = float textureInfo.realWidth
  and height = float textureInfo.realHeight
  in
(*   let () = add_mem textureInfo.memSize in *)
  let clipping = 
    if textureInfo.realHeight <> textureInfo.height || textureInfo.realWidth <> textureInfo.width 
    then Some (Rectangle.create 0. 0. (width /. (float textureInfo.width)) (height /. (float textureInfo.height)))
    else None 
  and kind =
    match textureInfo.texFormat with
    [ TextureFormatPallete palleteID -> 
      let pallete = loadPallete palleteID in
        Pallete pallete
    | TextureFormatAlpha -> Alpha
    | TextureLuminanceAlpha -> LuminanceAlpha
    | TextureFormatETC1WithAlpha alphaTexInfo -> EtcWithAlpha alphaTexInfo
    | _ -> Simple textureInfo.pma
    ]
  in
  let renderInfo = 
    {
      rtextureID = textureInfo.textureID;
      rwidth = width *. !scale;
      rheight = height *. !scale;
      clipping = clipping;
      kind = kind;
      rx = 0;
      ry = 0;
    }
  in
  object(self)
(*     value mutable textureID = renderInfo.rtextureID; *)
    value scale = !scale;
    method scale = scale;
    value renderInfo = renderInfo;
    method renderInfo = renderInfo;
    method kind = renderInfo.kind;
    method setFilter filter = set_texture_filter renderInfo.rtextureID filter;
    value mutable released = False;
    method released = released;
    method release () = 
      if not released
      then
      (

        debug:gc "release 's' texture: <%ld>" (int32_of_textureID renderInfo.rtextureID);
        delete_textureID renderInfo.rtextureID;
        released := True;
      ) else ();

      (*
      if (textureID <> 0) 
      then
      (
        debug "release texture <%d>" textureID;
        delete_texture textureID; 
        textureID := 0;
        texture_mem_sub mem;
      )
      else ();
      *)
    method width = renderInfo.rwidth;
    method height = renderInfo.rheight;
    method hasPremultipliedAlpha = True; (* CHECK THIS *)
    method textureID = renderInfo.rtextureID;
    method base : option c = None;
    method clipping = renderInfo.clipping;
    method rootClipping = renderInfo.clipping;
(*       method update path = ignore(loadImage ~textureID ~path ~contentScaleFactor:1.);  (* Fixme cache it *) *)
    value mutable subTextureCache = None;
    method subTexture region = 
      let clipping = 
        let tw = renderInfo.rwidth /. scale
        and th = renderInfo.rheight /. scale in
        Rectangle.create 
          (region.Rectangle.x /. tw) 
          (region.Rectangle.y /. th) 
          (region.Rectangle.width /. tw) 
          (region.Rectangle.height /. th) 
      in
      match subTextureCache with
      [ None -> 
        let st = ((new subtexture region clipping scale (self :> c)) :> c) in
        let sTexCache = SubTextureCache.create 1 in
        (
          subTextureCache := Some sTexCache;
          SubTextureCache.add sTexCache clipping st;
          st
        )
      | Some sTexCache -> 
        try
          SubTextureCache.find sTexCache clipping
        with [ Not_found -> 
          let st = ((new subtexture region clipping scale (self :> c)) :> c) in
          (
            SubTextureCache.add sTexCache clipping st;
            st
          )
        ]
      ];

    method addRenderer (_:renderer) = ();
    method removeRenderer (_:renderer) = ();
    (*
    initializer 
    (
      Gc.finalise (fun t -> (debug:gc "release texture <%d>" textureID; t#release ())) self;
      texture_mem_add mem;
    );
    *)
  end;


value make textureInfo = new s textureInfo;


value make_and_cache path textureInfo = 
(*   let mem = textureInfo.memSize in *)
(*   let finalizer t = if not t#released then TextureCache.remove cache path else () in *)
  let res = 
    object(self) 
      inherit s textureInfo as super;
      value path = path;
      method !release () = 
        if not released
        then
        (
          debug:gc "release cached texture: <%ld>" (int32_of_textureID renderInfo.rtextureID);
          delete_textureID renderInfo.rtextureID;
          TextureCache.remove cache path;
          released := True;
        )
        else ();

(*       initializer Gc.finalise (make_finalizer path) self; *)
        (*
        if (textureID <> 0) 
        then
        (
          debug "release texture <%d>" textureID;
          delete_texture textureID; 
          textureID := 0;
          texture_mem_sub mem;
          TextureCache.remove cache path;
        )
        else ();
        *)
    end
  in
  (
    debug:cache "texture <%d> cached" (int32_of_textureID res#textureID);
    TextureCache.add cache path res;
    (res :> c)
  );

value load ?(with_suffix=True) ?(filter=defaultFilter.val) ?(use_pvr=True) path : c = 
  let fpath = match with_suffix with [ True -> LightCommon.path_with_suffix path | False -> path ] in
  try
      debug:cache (
        Debug.d "print cache";
        TextureCache.iter (fun k _ -> Debug.d "image cache: %s" k) cache;
      );
      ((TextureCache.find cache fpath) :> c)
  with 
  [ Not_found ->
    let suffix =
      match with_suffix with
      [ True -> LightCommon.resources_suffix ()
      | False ->  None
      ]
    in
    let textureInfo = proftimer:t "Loading texture [%F]" with loadImage path suffix filter use_pvr in
    let () = 
      debug
        "loaded texture: %s <%ld> [%d->%d; %d->%d] [pma=%s]\n%!" 
        path (int32_of_textureID textureInfo.textureID) textureInfo.realWidth textureInfo.width textureInfo.realHeight textureInfo.height 
        (string_of_bool textureInfo.pma) 
    in
    make_and_cache fpath textureInfo
  ];



module type AsyncLoader = sig

  value load: bool -> string -> filter -> bool -> ((c -> unit) * (string -> unit)) -> unit;
  value check_result: unit -> unit;

end;


type aloader_runtime;
external aloader_create_runtime: unit -> aloader_runtime = "ml_texture_async_loader_create_runtime";
external aloader_push: aloader_runtime -> string -> option string -> filter -> bool -> unit = "ml_texture_async_loader_push";
external aloader_pop: aloader_runtime -> option (string * bool * option textureInfo) = "ml_texture_async_loader_pop";

module AsyncLoader(P:sig end) : AsyncLoader = struct

  value waiters = Hashtbl.create 1;
  value cruntime = aloader_create_runtime ();

  value load with_suffix path filter use_pvr callbacks = 
    let fpath = match with_suffix with [ True -> LightCommon.path_with_suffix path | False -> path ] in
    let () = debug:async "Load request %s<%b>" fpath with_suffix in 
    (
      if not (Hashtbl.mem waiters fpath)
      then 
        let suffix = 
          match with_suffix with
          [ True -> LightCommon.resources_suffix ()
          | False -> None
          ]
        in
        aloader_push cruntime path suffix filter use_pvr
      else ();
      Hashtbl.add waiters fpath callbacks
    );



  value rec check_result () = 
    if Hashtbl.length waiters > 0
    then
      match aloader_pop cruntime with
      [ Some (path,with_suffix,tInfo) -> 
        (
          let () = debug:async "Loaded %s with suffix %b" path with_suffix in
          let path =  
            match with_suffix with
            [ True -> LightCommon.path_with_suffix path
            | False -> path
            ]
          in
          let () = debug:async "make_and_cache: %s" path in
          let wtrs = MHashtbl.pop_all waiters path in
          let () = debug:async "rest waiters: [%s]" (String.concat ";" (ExtList.List.of_enum (MHashtbl.keys waiters))) in
          let () = debug:async "waiters cnt: %d" (List.length wtrs) in
          match tInfo with
          [ Some textureInfo -> 
            let texture = make_and_cache path textureInfo in
            (
              debug "texture: %s loaded" path;
              List.iter (fun (f,_) -> f texture) (List.rev wtrs);
            )
          | None -> List.iter (fun (_,f) -> f path) (List.rev wtrs)
          ];
					()
(*           check_result (); *)
        )
      | None -> ()
      ]
    else ();

end;


value async_loader = ref None; (* ссылка на модуль *) 

value check_async () =
  match !async_loader with
  [ Some m ->
    let module Loader = (value m:AsyncLoader) in
    Loader.check_result ()
  | None -> ()
  ];

value async_ecallback path = raise (Cant_load_texture path);

value load_async ?(with_suffix=True) ?(filter=defaultFilter.val) ?(use_pvr=True) path ?(ecallback=async_ecallback) callback = 
  let () = debug "start async load %s[%b]" path with_suffix in
  let texture = 
    try
      let path = match with_suffix with [ True -> LightCommon.path_with_suffix path | False -> path ] in
      (
        debug:cache (
          Debug.d "print cache";
          TextureCache.iter (fun k _ -> Debug.d "image cache: %s" k) cache;
        );
        Some (((TextureCache.find cache path) :> c))
      )
    with 
    [ Not_found -> None ]
  in
  match texture with
  [ Some t -> callback t (* FIXME: check filter *)
  | None ->
    let m =
      match !async_loader with
      [ Some m -> m
      | None -> 
          let module Loader = AsyncLoader (struct end) in
          let m = (module Loader:AsyncLoader) in
          (
            async_loader.val := Some m;
            m
          )
          
      ]
    in
    let module Loader = (value m:AsyncLoader) in
    Loader.load with_suffix path filter use_pvr (callback,ecallback)
  ];



(* Resizable texture *)



IFPLATFORM(ios android) 

external loadExternalImage: string -> (textureInfo -> unit) -> option (int -> string -> unit) -> unit = "ml_loadExternalImage";
value loadExternal url ~callback ~errorCallback =
  let url = ExtString.String.(if starts_with url "https://" then let (_, url) = replace url "https://" "http://" in url else url) in
  loadExternalImage url begin fun textureInfo ->
    let texture = make textureInfo in
    callback (texture :> c)
  end errorCallback;

ELSE

  value loadExternal url ~callback ~errorCallback = (); (* TODO: Get it by URLLoader *)
  
ENDPLATFORM;



value clear () = 
(
  PalleteCache.clear palleteCache;
  TextureCache.clear cache;
);

Callback.register "texture_cache_clear" clear;
