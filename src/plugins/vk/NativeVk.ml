module User =
	struct
		type gender = [= `male | `female | `none ];

		type t =
			{
				id: string;
				name: string;
				gender: gender;
				photo: string;
				online: bool;
				lastSeen: float;
			};

		value create id name gender photo online lastSeen = { id; name; gender = match gender with [ 1 -> `female | 2 -> `male | _ -> `none ]; photo; online; lastSeen };
		value id t = t.id;
		value name t = t.name;
		value gender t = t.gender;
		value photo t = t.photo;
		value online t = t.online;
		value lastSeen t = t.lastSeen;
		value toString t = Printf.sprintf "%s (id %s, gender %s, photo %s, online %B, lastSeen %f)" t.name t.id (match t.gender with [ `male -> "male" | `female -> "female" | `none -> "not specified"]) t.photo t.online t.lastSeen;
	end;

type t = unit;
type fail = string -> unit;

IFDEF PC THEN

value init () = ();
value authorize ~appid ~permissions ?fail ~success ?force () = ();
value friends ?fail ~success t = ();
value users ?fail ~success ~ids t = ();
value token _ = "";
value uid _ = "";
value logout _ = ();
value apprequest ?fail ~success ?request_type ~text ~user_id () = ();
ELSE
Callback.register "create_user" User.create;

external init: unit -> unit= "ml_vk_init";

external authorize: ~appid:string -> ~permissions:list string -> ?fail:fail -> ~success:(t -> unit) -> ~force:bool -> unit -> unit = "ml_vk_authorize_byte" "ml_vk_authorize";
value authorize ~appid ~permissions ?fail ~success ?(force = False) = authorize ~appid ~permissions ?fail ~success ~force;
external friends: ?fail:fail -> ~success:(list User.t -> unit) -> t -> unit = "ml_vk_friends";
external users: option fail -> (list User.t -> unit) -> string -> unit = "ml_vk_users";
value users ?fail ~success ~ids t =
	let ids = String.concat "," ids in
		users fail success ids;
external token: t -> string = "ml_vk_token";
external uid: t -> string = "ml_vk_uid";
external logout: unit -> unit= "ml_vk_logout";

(*not available for apps not in mobile catalog*)
external _apprequest:?fail:fail -> ~success:(string -> unit) -> ~user_id:string -> unit = "ml_vk_apprequest";
value apprequest ?fail ~success ?request_type ~text ~user_id () = _apprequest ?fail ~success ~user_id;
ENDIF;
