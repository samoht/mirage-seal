open V1
open V1_LWT

let (>>=) = Lwt.bind

(* Split a URI into a list of path segments *)
let split_path uri =
  let path = Uri.path uri in
  let rec aux = function
    | [] | [""] -> []
    | hd::tl -> hd :: aux tl
  in
  List.filter (fun e -> e <> "")
    (aux (Re_str.(split_delim (regexp_string "/") path)))

(* HTTP handler *)
module Dispatch (C:CONSOLE) (FS:KV_RO) (S:Cohttp_lwt.Server) = struct

  let read_fs fs name =
    FS.size fs name >>= function
    | `Error (FS.Unknown_key _) ->
      Lwt.fail (Failure ("read " ^ name))
    | `Ok size ->
      FS.read fs name 0 (Int64.to_int size) >>= function
      | `Error (FS.Unknown_key _) -> Lwt.fail (Failure ("read " ^ name))
      | `Ok bufs -> Lwt.return (Cstruct.copyv bufs)

  (* dispatch non-file URLs *)
  let rec dispatcher fs = function
    | [] | [""] -> dispatcher fs ["index.html"]
    | segments ->
      let path = String.concat "/" segments in
      Lwt.catch
        (fun () ->
           read_fs fs path >>= fun body ->
           S.respond_string ~status:`OK ~body ())
        (fun exn ->
           S.respond_not_found ())

end

(* HTTPS *)
module Main
    (C : CONSOLE) (S : STACKV4)
    (DATA : KV_RO) (KEYS: KV_RO)
    (Clock : CLOCK) =
struct

  module TCP  = S.TCPV4
  module TLS  = Tls_mirage.Make (TCP)
  module X509 = Tls_mirage.X509 (KEYS) (Clock)

  module Http     = Cohttp_mirage.Server(TLS)
  module Dispatch = Dispatch(C)(DATA)(Http)

  let log c fmt = Printf.ksprintf (C.log c) fmt

  let with_tls c cfg tcp ~f =
    let peer, port = TCP.get_dest tcp in
    let log str = log c "[%s:%d] %s" (Ipaddr.V4.to_string peer) port str in
    let with_tls_server k = TLS.server_of_flow cfg tcp >>= k in
    with_tls_server @@ function
    | `Error _ -> log "TLS failed"; TCP.close tcp
    | `Ok tls  -> log "TLS ok"; f tls >>= fun () ->TLS.close tls
    | `Eof     -> log "TLS eof"; TCP.close tcp

  let with_http c kv flow =
    let callback (_, cid) request body =
      let uri = Http.Request.uri request in
      let cid = Cohttp.Connection.to_string cid in
      log c "[%s] serving %s." cid (Uri.to_string uri);
      Dispatch.dispatcher kv (split_path uri)
    in
    let conn_closed (_,cid) =
      let cid = Cohttp.Connection.to_string cid in
      log c "[%s] closing." cid
    in
    let http = Http.make ~conn_closed ~callback () in
    Http.listen http flow () ()

  let tls_init kv =
    X509.certificate kv `Default >>= fun cert ->
    let conf = Tls.Config.server ~certificates:(`Single cert) () in
    Lwt.return conf

  let start c stack data keys _clock =
    tls_init keys >>= fun cfg ->
    let serve flow = with_tls c cfg flow ~f:(with_http c data) in
    S.listen_tcpv4 stack ~port:443 serve;
    S.listen stack

end
