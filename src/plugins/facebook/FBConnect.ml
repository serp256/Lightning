IFDEF IOS THEN

external ios_facebook_init : string -> unit = "ml_facebook_init";
  
value onInitAuthorizeLoggedCallback = ref None;
value onInitAuthorizeErrorCallback = ref None;
value init ?callback ?ecallback appid = 
  (
    ios_facebook_init appid;
    onInitAuthorizeLoggedCallback.val := callback;
    onInitAuthorizeErrorCallback.val := ecallback;
  );


(*** SESSION ***)
module Session = struct

  type status = [ NotAuthorized | Authorizing of Queue.t (bool -> unit) | Authorized ];

  value auth_status = ref NotAuthorized;
  value str_auth status = 
    match status with
    [ NotAuthorized -> "NotAuthorized"
    | Authorizing clbs -> "Authorizing " ^ (string_of_int (Queue.length clbs))
    | Authorized -> "Authorized"
    ];

  external ios_facebook_authorize : list string -> unit = "ml_facebook_authorize";

  value permissions = ref [];
  value isUserAuthorize = ref False;

  external ios_facebook_check_auth_token : unit -> bool = "ml_facebook_check_auth_token";
  external ios_facebook_get_auth_token : unit -> string = "ml_facebook_get_auth_token";

  value get_auth_token = ios_facebook_get_auth_token;

  value facebook_logged_in () = 
  (
    match !isUserAuthorize with
    [ True -> 
      (
        match !auth_status with
        [ Authorizing callbacks -> (* call pending callbacks *)
          (
            while not (Queue.is_empty callbacks) do
              let c = Queue.pop callbacks in
              c True
            done;
          )
        | _ -> failwith "Invalid auth status"
        ];
        isUserAuthorize.val := False 
      )
    | _ -> 
        match !onInitAuthorizeLoggedCallback with
        [ Some f -> f True
        | _ -> ()
        ]
    ];
    auth_status.val := Authorized;
  );

  value facebook_session_invalidated () = 
  (  
    match !isUserAuthorize with
    [ True -> 
        (
          match !auth_status with
          [ Authorizing callbacks ->
            (
              while not (Queue.is_empty callbacks) do
                let c = Queue.pop callbacks in
                c False
              done;
            )
          | _ -> ()
          ];
          isUserAuthorize.val := False
        )
    | _ -> 
        match !onInitAuthorizeErrorCallback with
        [ Some f -> f False
        | _ -> ()
        ]
    ];
    auth_status.val := NotAuthorized;
  );

  value facebook_logged_out  = facebook_session_invalidated;
  value facebook_login_cancelled  = facebook_session_invalidated;

  value authorize perms = 
    match ios_facebook_check_auth_token () with
    [ True  -> facebook_logged_in ()
    | False -> ios_facebook_authorize perms
    ];
  

  value with_auth_check callback = 
    match !auth_status with
    [ Authorized -> callback True
    | Authorizing callbacks -> Queue.add callback callbacks
    | NotAuthorized -> 
        let callbacks = Queue.create () in
        (
          isUserAuthorize.val := True;
          Queue.push callback callbacks;
          auth_status.val := Authorizing callbacks;
          authorize !permissions
        )
    ];



  Callback.register "facebook_logged_in" facebook_logged_in;
  Callback.register "facebook_login_cancelled" facebook_login_cancelled;
  Callback.register "facebook_logged_out" facebook_logged_out;
  Callback.register "facebook_session_invalidated" facebook_session_invalidated;
  
end;


(*** GRAPH API ***)
module GraphAPI = struct

type delegate = 
{
  fb_request_did_fail   : option (string -> unit);    
  fb_request_did_load   : option (Ojson.t -> unit)
};

value delegates = Hashtbl.create 1;

external ios_facebook_request_with_graph_api_and_params : string -> list (string*string) -> int -> unit = "ml_facebook_request";

(* graph api request *)

value _request graph_path params ?delegate () = 
  let requestID = Random.int 10000 in
  (
    match delegate with
    [ Some d -> Hashtbl.add delegates requestID d
    | None -> ()
    ];
    
    ios_facebook_request_with_graph_api_and_params graph_path params requestID
  );

value request graph_path params ?delegate () = 
  let f = (fun _ -> _request graph_path params ?delegate:delegate ())
  in 
    (
      Session.with_auth_check f;
    );


(* *)
value facebook_request_did_fail requestID error_str = 
  try 
    (
      let delegate = Hashtbl.find delegates requestID in
      match delegate.fb_request_did_fail with
      [ Some f -> f error_str
      | _ -> ()
      ];
      
      Hashtbl.remove delegates requestID;
    )
  with [ Not_found -> () ];




(* *)
value facebook_request_did_load requestID json_str = 
  let json_data = Ojson.from_string json_str in
  match json_data with
  [ `Assoc data ->
    try 
      ignore(List.assoc "error" data) (* если есть такой ключ, то будет вызван facebook_request_did_fail *)
    with 
    [ Not_found ->
        try 
          (
            let delegate = Hashtbl.find delegates requestID in
            match delegate.fb_request_did_load with
            [ Some f -> f json_data
            | _ -> ()
            ];
      
            Hashtbl.remove delegates requestID;
          )
        with [ Not_found -> () ]
    ]
  | _ -> facebook_request_did_fail requestID "The operation couldn’t be completed. (facebookErrDomain error 10000.)" 
  ];
  

Callback.register "facebook_request_did_fail" facebook_request_did_fail;
Callback.register "facebook_request_did_load" facebook_request_did_load;
  
end;



(*** DIALOGS ***)

module Dialog = struct

type delegate = 
{
  fb_dialog_did_complete              : option (unit -> unit);
  fb_dialog_did_cancel                : option (unit -> unit);
  fb_dialog_did_fail                  : option (string -> unit)
};

type users_filter = [ All | AppUsers | NonAppUsers ];

value string_of_users_filter filter = 
  match filter with
  [ All -> "all"
  | AppUsers -> "app_users"
  | NonAppUsers -> "app_non_users"
  ];

value delegates = Hashtbl.create 1;

external ios_facebook_open_apprequest_dialog : string -> string -> string -> string -> int -> unit = "ml_facebook_open_apprequest_dialog";

(* apprequest dialog *)
value _apprequest ?(message="") ?(recipients=[]) ?(filter=All) ?(title="") ?delegate () = 
  let dialogID = Random.int 10000 in
  (
    match delegate with
    [ Some d -> Hashtbl.add delegates dialogID d
    | None -> ()
    ];
    
    let recipientsStr = 
    match recipients with 
    [ []    -> ""
    | _     -> ExtString.String.join "," recipients
    ] 
    in ios_facebook_open_apprequest_dialog message recipientsStr (string_of_users_filter filter) title dialogID
  );
  

value apprequest ?(message="") ?(recipients=[]) ?(filter=All) ?(title="") ?delegate () = 
  let f = (fun _ -> _apprequest ~message ~recipients ~filter ?delegate ())
  in 
    (
      Session.with_auth_check f;
    );



(* success *)
value facebook_dialog_did_complete dialogID = 
  try
    let delegate = Hashtbl.find delegates dialogID in
    (
      Hashtbl.remove delegates dialogID;
      match delegate.fb_dialog_did_complete with
      [ Some f -> f ()
      | None -> ()
      ]
    )
  with [ Not_found -> () ];


(* *)
value facebook_dialog_did_cancel dialogID = 
  try
    let delegate = Hashtbl.find delegates dialogID in
    (
      Hashtbl.remove delegates dialogID;
      match delegate.fb_dialog_did_cancel with
      [ Some f -> f ()
      | None -> ()
      ]
    )
  with [ Not_found -> () ];
  


(* *)
value facebook_dialog_did_fail_with_error dialogID error =   
  try
    let delegate = Hashtbl.find delegates dialogID in
    (
      Hashtbl.remove delegates dialogID;
      match delegate.fb_dialog_did_fail with
      [ Some f -> f error
      | None -> ()
      ]
    )
  with [ Not_found -> () ];


Callback.register "facebook_dialog_did_complete" facebook_dialog_did_complete;
Callback.register "facebook_dialog_did_cancel" facebook_dialog_did_cancel;
Callback.register "facebook_dialog_did_fail_with_error" facebook_dialog_did_fail_with_error;
Random.self_init ();
end;
  

ELSE 
IFDEF ANDROID THEN

external facebook_init : string -> unit = "ml_fb_init";
value init ?callback ?ecallback appid = 
  (
    facebook_init appid; 
  );

(*** SESSION ***)
module Session = struct

  type status = [ NotAuthorized | Authorizing of Queue.t (bool -> unit) | Authorized ];

  value auth_status = ref NotAuthorized;

  external android_fb_auth : int -> list string -> (unit -> unit) -> (unit -> unit) -> unit = "ml_fb_authorize";

  value fb_auth perms callback ecallback = android_fb_auth (List.length perms) perms callback ecallback;

  value permissions = ref [];

  external android_facebook_check_auth_token : unit -> bool = "ml_fb_check_auth_token";
  external get_auth_token : unit -> string = "ml_fb_get_auth_token";
  (* value get_auth_token () = ""; *)

  value facebook_logged_in () = 
  (
    match !auth_status with
    [ Authorizing callbacks -> (* call pending callbacks *)
      (
        while not (Queue.is_empty callbacks) do
          let c = Queue.pop callbacks in
          c True
        done;
      )
    | _ -> failwith "Invalid auth status"
    ];
  
    auth_status.val := Authorized;
  );

  value facebook_session_invalidated () = 
  (  
    match !auth_status with
    [ Authorizing callbacks ->
      (
        while not (Queue.is_empty callbacks) do
          let c = Queue.pop callbacks in
          c False
        done;
      )
    | _ -> ()
    ];
  
    auth_status.val := NotAuthorized;
  );

  value authorize perms = 
    match android_facebook_check_auth_token () with
    [ True  -> facebook_logged_in ()
    | False -> fb_auth perms facebook_logged_in facebook_session_invalidated
    ];
  

  value with_auth_check callback = 
    match !auth_status with
    [ Authorized -> callback True
    | Authorizing callbacks -> Queue.add callback callbacks
    | NotAuthorized -> 
        let callbacks = Queue.create () in
        (
          Queue.push callback callbacks;
          auth_status.val := Authorizing callbacks;
          authorize !permissions
        )
    ];

end;

(*** GRAPH API ***)
module GraphAPI = struct

  type delegate = 
  {
    fb_request_did_fail   : option (string -> unit);    
    fb_request_did_load   : option (Ojson.t -> unit)
  };

  external fb_graph_api : ?callback:(string -> unit) -> ?ecallback:(string -> unit) -> string -> int -> list (string*string) -> unit = "ml_fb_graph_api"; (* success callback, error callback, path, length params, params, *)

  value request graph_path params ?delegate () =  
    let (callback, ecallback) =    
      match delegate with
      [ Some d ->
          match d.fb_request_did_load with
          [ Some cb ->
              let callback str =
                let json = Ojson.from_string str in
                match json with
                [ `Assoc data -> 
                    try 
                      (
                        ignore(List.assoc "error" data);
                        match d.fb_request_did_fail with
                        [ Some f -> f str
                        | _ -> ()
                        ]
                      )
                    with 
                      [ Not_found -> cb json ]
                | _ -> 
                    match d.fb_request_did_fail with
                    [ Some f -> f "The operation couldn’t be completed. (facebookErrDomain error 10000.)"
                    | _ -> ()
                    ]
                ]
              in
              (Some callback, d.fb_request_did_fail)
          | _ -> (None, d.fb_request_did_fail)
          ]
      | _ -> (None, None)
      ]
    in    
      Session.with_auth_check (fun _ -> fb_graph_api ?callback ?ecallback graph_path (List.length params) params);
(*
    Session.with_auth_check (fun _ -> fb_graph_api graph_path (List.length params) params ?callback:(Some (fun str -> ())) ?ecallback:None);
*)
end;



(*** DIALOGS ***)
module Dialog = struct
  type delegate = 
  {
    fb_dialog_did_complete : option (unit -> unit);
    fb_dialog_did_cancel : option (unit -> unit);
    fb_dialog_did_fail : option (string -> unit)
  };

  type users_filter = [ All | AppUsers | NonAppUsers ];

  value string_of_users_filter filter = 
    match filter with
    [ All -> "all"
    | AppUsers -> "app_users"
    | NonAppUsers -> "app_non_users"
    ];

  external facebook_open_apprequest_dialog : string -> string -> string -> string -> option delegate -> unit = "ml_facebook_open_apprequest_dialog";

  value _apprequest ?(message="") ?(recipients=[]) ?(filter=All) ?(title="") ?delegate () = 
    let recipientsStr = 
      match recipients with 
      [ [] -> ""
      | _ -> ExtString.String.join "," recipients
      ] 
    in
      facebook_open_apprequest_dialog message recipientsStr (string_of_users_filter filter) title delegate;

  value apprequest ?(message="") ?(recipients=[]) ?(filter=All) ?(title="") ?delegate () = 
    Session.with_auth_check (fun _ -> _apprequest ~message ~recipients ~filter ?delegate ());
end;

ELSE 

value init ?callback ?ecallback appid = ();

module Session = struct
  value permissions = ref [];
  value get_auth_token () = "";
  value authorize _ = ();
  value with_auth_check _ = ();
end;


(*** GRAPH API ***)
module GraphAPI = struct

  type delegate = 
  {
    fb_request_did_fail   : option (string -> unit);    
    fb_request_did_load   : option (Ojson.t -> unit)
  };

  value request graph_path params ?delegate () = (); 
end;



(*** DIALOGS ***)
module Dialog = struct
  type delegate = 
  {
    fb_dialog_did_complete              : option (unit -> unit);
    fb_dialog_did_cancel                : option (unit -> unit);
    fb_dialog_did_fail                  : option (string -> unit)
  };

  type users_filter = [ All | AppUsers | NonAppUsers ];

  value apprequest ?(message="") ?(recipients=[]) ?(filter=All) ?(title="") ?delegate () = ();
end;

ENDIF;
ENDIF;
