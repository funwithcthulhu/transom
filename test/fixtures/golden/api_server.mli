module type HANDLERS = sig
  val echo :
    Api_t.echo_req ->
    (Api_t.echo_res, Transom_runtime.Error.t) result
end

module Make (_ : HANDLERS) : sig
  val dispatch :
    method_:string ->
    params:Yojson.Safe.t ->
    emit:(Yojson.Safe.t -> unit) ->
    (Yojson.Safe.t, Transom_runtime.Error.t) result

  val run_stdio : unit -> unit
end
