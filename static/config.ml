open Mirage

let red fmt = Printf.sprintf ("\027[31m"^^fmt^^"\027[m")
let red_s = red "%s"
let err fmt =
  Printf.kprintf (fun str ->
      Printf.eprintf "%s %s\n%!" (red_s "[ERROR] ") str;
      exit 1
    ) fmt

let get ?default ?(lower=true) name f =
  let name = "SEAL_" ^ name in
  let normalize = if lower then String.lowercase else (fun x -> x) in
  try Unix.getenv name |> normalize |> f
  with Not_found ->
    match default with
    | None   -> err "%s is not set" name
    | Some d -> d

let get_path ?default name f =
  get ?default ~lower:false name f

let bool_of_env = function
  | "" | "0" | "false" -> false
  | _  -> true

(* Network configuration *)

let ip = Ipaddr.V4.of_string_exn
let address = get "ADDRESS" ~default:(ip "10.0.0.2") ip
let netmask = get "NETMASK" ~default:(ip "255.255.255.0") ip
let gateway = get "GATEWAY" ~default:(ip "10.0.0.1") ip
let address = { address; netmask; gateways = [gateway] }

let net =
  get "NET" ~default:`Direct  (function "socket" -> `Socket | _ -> `Direct)

let dhcp = get "DHCP" ~default:true bool_of_env

let stack =
  match net, dhcp with
  | `Direct, true  -> direct_stackv4_with_dhcp default_console tap0
  | `Direct, false -> direct_stackv4_with_static_ipv4 default_console tap0 address
  | `Socket, _     -> socket_stackv4 default_console [Ipaddr.V4.any]

(* storage configuration *)

let data =
  get_path "DATA" (fun dir ->
      if Sys.file_exists dir && Sys.is_directory dir then dir
      else err "%s is not a valid directory." dir
    )
  |> crunch

let keys () =
  get_path "KEYS" (fun dir ->
      let pem = Filename.concat dir "tls/server.pem" in
      let key = Filename.concat dir "tls/server.key" in
      let file_exists f = Sys.file_exists f && not (Sys.is_directory f) in
      if file_exists pem && file_exists key then dir
      else err "Cannot find %s/tls/server.{pem,key}." dir
    )
  |> crunch

let with_https = get "HTTPS" ~default:false bool_of_env

(* main app *)

let https =
  foreign "Dispatch.HTTPS"
    (console @-> stackv4 @-> kv_ro @-> kv_ro @-> clock @-> job)

let http =
  foreign "Dispatch.HTTP"
    (console @-> stackv4 @-> kv_ro @-> clock @-> job)

let () =
  let ocamlfind = [
    "uri"; "tls"; "tls.mirage"; "mirage-http"; "magic-mime"
  ] in
  let opam = ["uri"; "tls"; "mirage-http"; "magic-mime"] in
  add_to_ocamlfind_libraries ocamlfind;
  add_to_opam_packages opam;
  register "seal" [
    match with_https with
    | true  -> https
               $ default_console
               $ stack
               $ data
               $ keys ()
               $ default_clock
    | false -> http
               $ default_console
               $ stack
               $ data
               $ default_clock
  ]
