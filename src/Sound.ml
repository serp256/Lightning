value ev_SOUND_COMPLETE = Ev.gen_id "SOUND_COMPLETE";

exception Audio_error of string;

type category =
  [ AmbientSound
  | SoloAmbientSound
  | MediaPlayback
  | RecordAudio
  | PlayAndRecord
  | AudioProcessing
  ];

type sound_state = [ SoundInitial | SoundPlaying | SoundPaused | SoundStoped ];

class type virtual channel  =
  object
    inherit EventDispatcher.simple [ channel ];
    method play: unit -> unit;
    method pause: unit -> unit;
    method stop: unit -> unit;
    method setVolume: float -> unit;
    method volume: float;
    method setLoop: bool -> unit;
    method state: sound_state;
  end;


Callback.register_exception "Audio_error" (Audio_error "");

IFDEF IOS THEN

external init': category -> unit -> unit = "ml_sound_init";

value init () = init' AmbientSound ();

type albuffer;
type alsound =
  {
    albuffer: albuffer;
    duration: float;
  };

type avsound = string;

type sound = [ ALSound of alsound | AVSound of avsound ];

external albuffer_create: string -> alsound = "ml_albuffer_create";
external al_setMasterVolume: float -> unit = "ml_al_setMasterVolume";

value setMasterVolume = al_setMasterVolume;

value load path =
  match ExtString.String.ends_with path ".caf" with
  [ True    -> ALSound (albuffer_create path)
  | False   -> AVSound path
  ];

type alsource = int32;
external alsource_create: albuffer -> alsource = "ml_alsource_create";
external alsource_play: alsource -> unit = "ml_alsource_play";
external alsource_setVolume: alsource -> float -> unit = "ml_alsource_setVolume";
external alsource_getVolume: alsource -> float = "ml_alsource_getVolume";
external alsource_setLoop: alsource -> bool -> unit = "ml_alsource_setLoop";
external alsource_stop: alsource -> unit = "ml_alsource_stop";
external alsource_pause: alsource -> unit = "ml_alsource_pause";
external alsource_delete: alsource -> unit = "ml_alsource_delete";
external alsource_state: alsource -> sound_state = "ml_alsource_state" "noalloc";



(* ALSound *)
class al_channel snd =
  let sourceID = alsource_create snd.albuffer in
  let finalize _ = (debug "finalize al_channel"; alsource_delete sourceID) in
  object(self)
    inherit EventDispatcher.simple [ channel ];
    initializer Gc.finalise finalize self;
    value sound = snd;
    value mutable loop = False;
    value mutable startMoment = 0.;
    value mutable pauseMoment = 0.;
    value mutable timer_id = None;

    method private asEventTarget = (self :> channel);

    method play () =
    (
      debug "play sound for IOS";
      alsource_play sourceID;
      timer_id := Some (Timers.start (* sound.duration *)10. self#finished);
    );

    method private finished () =
      let () = debug "sound finished" in
      if loop then
        timer_id := Some (Timers.start sound.duration self#finished)
      else (
        timer_id := None;
        self#dispatchEvent (Ev.create ev_SOUND_COMPLETE ());
      );

    method pause () =
      match timer_id with
      [ Some tid ->
        (
          Timers.stop tid;
          alsource_pause sourceID;
          timer_id := None;
        )
      | None -> ()
      ];

    method stop () =
      let () = debug "stop sound" in
      match timer_id with
      [ Some tid ->
        (
          Timers.stop tid;
          alsource_stop sourceID;
          timer_id := None;
        )
      | None -> ()
      ];
    method setVolume v = alsource_setVolume sourceID v;
    method volume = alsource_getVolume sourceID;
    method setLoop v =
    (
      loop := v;
      alsource_setLoop sourceID v;
    );

    method state = alsource_state sourceID;
  end;


type avplayer;

external avsound_create_player : avsound -> avplayer = "ml_avsound_create_player";
(* external avsound_release : avplayer -> unit = "ml_avsound_release"; *)
external avsound_play : avplayer -> (unit -> unit) -> unit = "ml_avsound_play";
external avsound_pause : avplayer -> unit = "ml_avsound_pause";
external avsound_stop : avplayer -> unit = "ml_avsound_stop";
external avsound_set_volume : avplayer -> float -> unit = "ml_avsound_set_volume";
external avsound_get_volume : avplayer -> float = "ml_avsound_get_volume";
external avsound_set_loop : avplayer -> bool -> unit = "ml_avsound_set_loop";
external avsound_is_playing : avplayer -> bool = "ml_avsound_is_playing";


(* AVSound *)
class av_channel snd =
  let player = avsound_create_player snd in
  object(self)

    inherit EventDispatcher.simple [ channel ];

    value mutable paused = False;

    method private asEventTarget = (self :> channel);
    method private onSoundComplete () = self#dispatchEvent (Ev.create ev_SOUND_COMPLETE ());
    method play () =
    (
      debug "play avsound";
      paused := False;
      avsound_play player self#onSoundComplete;
    );

    method private isPlaying () = avsound_is_playing player;

    method pause () =
    (
      debug "pause avsound";
      paused := True;
      avsound_pause player;
    );

    method stop () =
    (
      debug "stop avsound";
      paused := False;
      avsound_stop player;
    );

    method setVolume (v:float) =
    (
      debug "setVolume avsound";
      avsound_set_volume player v;
    );

    method volume =
    (
      debug "volume avsound";
      avsound_get_volume player;
    );

    method setLoop loop  =
    (
      debug "set loop avsound";
      avsound_set_loop player loop;
    );

    method state = match (paused, self#isPlaying ()) with
    [ (_, True)         -> SoundPlaying
    | (True, False)     -> SoundPaused
    | (False, False)    -> SoundStoped
    ];
  end;



value createChannel snd =
  match snd with
  [ ALSound als -> new al_channel als
  | AVSound avs -> new av_channel avs
  ];


ELSE
  IFDEF ANDROID THEN
    type avplayer;

    type alsound;
    type alplayer;

    type sound = [ ALSound of alsound | AVSound of string ];

    external init : unit -> unit = "ml_alsoundInit";

    value setMasterVolume (v:float) = (); (* fixme *)

    external alsoundLoad : string -> alsound = "ml_alsoundLoad";
    external alsoundPlay : alsound -> int -> bool -> (unit -> unit) -> alplayer = "ml_alsoundPlay";
    external alsoundPause : alplayer -> unit = "ml_alsoundPause";
    external alsoundStop : alplayer -> unit = "ml_alsoundStop";
    external alsoundSetVolume : alplayer -> int -> unit = "ml_alsoundSetVolume";
    external alsoundSetLoop : alplayer -> bool -> unit = "ml_alsoundSetLoop";

    external avsound_create_player : string -> avplayer = "ml_avsound_create_player";
    external avsound_setLoop : avplayer -> bool -> unit = "ml_avsound_set_loop";
    external avsound_setVolume : avplayer -> int -> unit = "ml_avsound_set_volume";
    external avsound_play : avplayer -> (unit -> unit) -> unit = "ml_avsound_play";
    external avsound_stop : avplayer -> unit = "ml_avsound_stop";
    external avsound_pause : avplayer -> unit = "ml_avsound_pause";
    external avsound_release : avplayer -> unit = "ml_avsound_release";

    value load path =
      if ExtString.String.ends_with path ".caf" then
        ALSound (alsoundLoad path)
      else
        AVSound path;

  class av_channel snd =
    let player = avsound_create_player snd in
    let finalize _ = (debug "finalize av_channel"; avsound_release player) in
    object(self)
      inherit EventDispatcher.simple [ channel ];

      value mutable isPlaying = False;
      value mutable paused = False;
      value mutable completed = False;
      value mutable volume = 1.;

      initializer Gc.finalise finalize self;

      method private asEventTarget = (self :> channel);

      method private onSoundComplete () =
      (
        completed := True;
        self#dispatchEvent (Ev.create ev_SOUND_COMPLETE ());
      );

      method play () =
      (
        isPlaying := True;
        paused := False;
        completed := False;
        avsound_play player self#onSoundComplete;
      );

      method pause () =
        if isPlaying then
        (
          paused := True;
          completed := False;
          isPlaying := False;

          avsound_pause player;
        )
        else ();

      method stop () =
        if paused || isPlaying then
        (
          paused := False;
          completed := False;
          isPlaying := False;

          avsound_stop player;
        )
        else ();

      method setVolume v =
      (
        volume := v;
        avsound_setVolume player (int_of_float (volume *. 100.));
      );

      method volume = volume;

      method setLoop loop  = avsound_setLoop player loop;

      method state = match (paused, isPlaying) with
      [ (_, True)         -> SoundPlaying
      | (True, False)     -> SoundPaused
      | (False, False)    -> SoundStoped
      ];
    end;

    class al_channel snd =
      object(self)
        inherit EventDispatcher.simple [ channel ];

				value sound = snd;
        value mutable stream = None;
        value mutable volume = 1.;
        value mutable loop = False;
        value mutable state = SoundInitial;

        method private asEventTarget = (self :> channel);

        method play () =
        (
						debug "play\n%!";
          stream := Some (alsoundPlay sound (int_of_float (volume *. 100.)) loop self#finished);
          state := SoundPlaying;
        );

        method private finished () =
				(
          stream := None;
          self#dispatchEvent (Ev.create ev_SOUND_COMPLETE ());
          state := SoundStoped;
				);

        method pause () =
          match stream with
          [ Some stream ->
            (
              alsoundPause stream;
              state := SoundPaused;
            )
          | _ -> ()
          ];

        method stop () =
          match stream with
          [ Some strm ->
            (
              stream := None;
              alsoundStop strm;
              state := SoundStoped;
            )
          | _ -> ()
          ];

        method setVolume v =
        (
          volume := v;

          match stream with
          [ Some stream -> alsoundSetVolume stream (int_of_float (v *. 100.))
          | _ -> ()
          ];
        );

        method volume = volume;

        method setLoop v =
        (
          loop := v;

          match stream with
          [ Some stream -> alsoundSetLoop stream v
          | _ -> ()
          ];
        );

        method state = state;
      end;

    (* value createChannel snd = new al_channel snd; *)
    (* value createChannel snd = new av_channel snd; *)
    value createChannel snd =
      match snd with
      [ ALSound als -> new al_channel als
      | AVSound avs -> new av_channel avs
      ];
  ELSE
    (* Sdl version here *)

    value init (*?category*) () = ();
    value setMasterVolume (_p:float) = ();
    type sound = int;
    value load (path:string) = 0;
    class ch snd =
      object(self)
        inherit EventDispatcher.simple [ channel ];
        method private asEventTarget = (self :> channel);
        method play () = ();
        method pause () = ();
        method stop () = ();
        method setVolume (v:float) = ();
        method volume = 1.;
        method setLoop (b:bool) = ();
        method state = SoundInitial;
      end;


    value createChannel snd = new ch snd;
  ENDIF;
ENDIF;
