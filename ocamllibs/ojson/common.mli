(* $Id: common.mli 62 2011-03-07 22:34:08Z mjambon $ *)

exception Json_error of string

val json_error : string -> 'a

val is_object_or_array: Type.json -> bool

type lexer_state = {
  buf : Bi_outbuf.t;
    (** Bi_outbuf used to accumulate substrings *)
  
  mutable lnum : int;
    (** Current line number (counting from 1) *)

  mutable bol : int;
    (** Absolute position of the first character of the current line
        (counting from 0) *)

  mutable fname : string option;
    (** Name referencing the input file in error messages *)
}

module Lexer_state :
sig
  type t = lexer_state = {
    buf : Bi_outbuf.t;
    mutable lnum : int;
    mutable bol : int;
    mutable fname : string option;
  }
end

val init_lexer :
  ?buf: Bi_outbuf.t ->
  ?fname: string ->
  ?lnum: int -> 
  unit -> lexer_state
  (** Create a fresh lexer_state record. *)


(**/**)
(* begin undocumented section *)

exception End_of_array
exception End_of_object
exception End_of_tuple
exception End_of_input

val utf8_of_bytes: Bi_outbuf.t -> int -> int -> int -> int -> unit
(* end undocumented section *)
(**/**)
