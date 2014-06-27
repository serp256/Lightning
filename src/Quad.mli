open LightCommon;

class c: [ ?color:color ] -> [ float ] -> [ float ] ->
  object
    inherit DisplayObject.c; 
(*       value vertexColors: array int; *)
(*       value vertexCoords: Bigarray.Array1.t float Bigarray.float32_elt Bigarray.c_layout; *)
(*       method updateSize: float -> float -> unit; *)
(*       method copyVertexCoords: Bigarray.Array1.t float Bigarray.float32_elt Bigarray.c_layout -> unit; *)
    method filters: list Filters.t;
    method setFilters: list Filters.t -> unit;
    method setColor: color -> unit;
    method color: color;
    method boundsInSpace: !'space. ?withMask:bool -> option (<asDisplayObject: DisplayObject.c; .. > as 'space) -> Rectangle.t;
    method private render': ?alpha:float -> ~transform:bool -> option Rectangle.t -> unit;
  end;

(* value cast: #DisplayObject.c -> option c;  *)
value create: ?color:color -> float -> float -> c;
