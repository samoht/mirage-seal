open Mirage

let err fmt = Printf.kprintf failwith fmt

let get ?default name f =
  let name = "SEAL_" ^ name in
  try Unix.getenv name |> String.lowercase |> f
  with Not_found ->
    match default with
    | None   -> err "%s is not set" name
    | Some d -> d

(* Network configuration *)

let ip = Ipaddr.V4.of_string_exn
let address = get "ADDRESS" ~default:(ip "10.0.0.2") ip
let netmask = get "NETMASK" ~default:(ip "255.255.255.0") ip
let gateway = get "GATEWAY" ~default:(ip "10.0.0.1") ip
let address = { address; netmask; gateways = [gateway] }

let net =
  get "NET" ~default:`Direct  (function "socket" -> `Socket | _ -> `Direct)

let dhcp =
  get "DHCP" ~default:true (function "0" | "false" -> false | _  -> true)

let stack =
  match net, dhcp with
  | `Direct, true  -> direct_stackv4_with_dhcp default_console tap0
  | `Direct, false -> direct_stackv4_with_static_ipv4 default_console tap0 address
  | `Socket, _     -> socket_stackv4 default_console [Ipaddr.V4.any]

(* storage configuration *)

let data =
  get "DATA" (fun dir ->
      if Sys.file_exists dir && Sys.is_directory dir then dir
      else err "%s is not a valid directory." dir
    )

let keys =
  get "KEYS" (fun dir ->
      let pem = Filename.concat dir "tls/server.pem" in
      let key = Filename.concat dir "tls/server.key" in
      let file_exists f = Sys.file_exists f && not (Sys.is_directory f) in
      if file_exists pem && file_exists key then dir
      else err "Cannot find %s/tls/server.{pem,key}." dir
    )

let data = crunch data
let keys = crunch keys

(* main app *)

let main =
  foreign "Dispatch.Main"
    (console @-> stackv4 @-> kv_ro @-> kv_ro @-> clock @-> job)

let () =
  let ocamlfind = ["re.str"; "uri"; "tls"; "tls.mirage"; "mirage-http"] in
  let opam = ["re"; "uri"; "tls"; "mirage-http"] in
  add_to_ocamlfind_libraries ocamlfind;
  add_to_opam_packages opam;
  register "seal" [
    main
    $ default_console
    $ stack
    $ data
    $ keys
    $ default_clock
  ]
