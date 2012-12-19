
value default_font_family: ref string;
value default_font_size : ref int;

type img_valign = [= `aboveBaseLine | `underBaseLine | `centerBaseLine | `default ];
type img_attribute = 
  [= `width of float
  | `height of float
  | `paddingLeft of float
  | `paddingRight of float
  | `paddingTop of float
  | `valign of img_valign
  ];

type img_attributes = list img_attribute;

type span_attribute = 
  [= `fontFamily of string
  | `fontSize of int
  | `fontWeight of string
  | `color of int
  | `alpha of float
  | `backgroundColor of int (* как это замутить то я забыла *)
  | `backgroundAlpha of float 
  ];

type span_attributes = list span_attribute;

type simple_element = [= `img of (img_attributes * DisplayObject.c) | `span of (span_attributes * simple_elements) | `br | `substring of (string*int*int) | `text of string ]
and simple_elements = list simple_element;

type p_halign = [= `left | `right | `center ];
type p_valign = [= `top | `bottom | `center ];
type p_attribute = 
  [= span_attribute
  | `halign of p_halign
  | `valign of p_valign
  | `spaceBefore of float
  | `spaceAfter of float
  | `textIndent of float
  ];

type p_attributes = list p_attribute;

type div_attribute = 
  [= span_attribute 
  | p_attribute
  | `paddingTop of float
  | `paddingLeft of float
  ];


type div_attributes = list div_attribute;


(* type attribute = [= div_attribute | p_attribute | span_attribute ]; *)

type main = 
  [= `div of (div_attributes * (list main))
  | `p of (p_attributes * simple_elements)
  ];

value img: ?width:float -> ?height:float -> ?paddingLeft:float -> ?paddingTop:float -> ?paddingRight:float -> ?valign:img_valign -> #DisplayObject.c -> simple_element;
value span: ?fontWeight:string -> ?fontFamily:string -> ?fontSize:int -> ?color:int -> ?alpha:float -> simple_elements -> simple_element;
value p: ?fontWeight:string -> ?fontFamily:string -> ?fontSize:int -> ?color:int -> ?alpha:float -> ?halign:p_halign -> ?valign:p_valign -> ?spaceBefore:float -> ?spaceAfter:float -> ?textIndent:float -> simple_elements -> main;
value parse_simples: ?imgLoader:(string -> DisplayObject.c) -> string -> simple_elements;
value parse: ?imgLoader:(string -> DisplayObject.c) -> string -> main;
value to_string: main -> string;
value create: ?width:float -> ?height:float -> ?border:int -> ?dest:#Sprite.c -> main -> ( (float*float) * DisplayObject.c);
