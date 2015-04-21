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
let address = get "ADDRESS" ~default:(ip "10.0.0.2")
let netmask = get "NETMASK" ~default:(ip "255.255.255.0")
let gateway = get "GATEWAY" ~default:(ip "10.0.0.1")
let address = { address; netmask; gateways = [gateway] }

let net =
  get "NET" ~default:`Direct  (function "socket" -> `Socket | _ -> `Direct)

let dhcp =
  get "DHCP" ~default:true (function "0" | "false" -> false | _  -> true)

let stack =
  match net, dhcp with
  | `Direct, true  -> direct_stackv4_with_dhcp default_console tap0
  | `Direct, false -> direct_stackv4_with_default_ipv4 default_console tap0
  | `Socket, _     -> socket_stackv4 default_console [Ipaddr.V4.any]

(* storage configuration *)

let dir =
  get "DIR" (fun dir ->
      if Sys.file_exists dir && Sys.is_directory dir then dir
      else err "%s is not a valid directory." dir
    )

let dir = crunch dir

(* main app *)

let main =
  foreign "Dispatch.Main"
    (console @-> stackv4 @-> kv_ro @-> entropy @-> clock @-> job)

let () =
  let ocamlfind = ["re.str"; "uri"; "tls"; "tls.mirage"; "mirage-http"] in
  let opam = ["re"; "uri"; "tls"; "mirage-http"] in
  add_to_ocamlfind_libraries ocamlfind;
  add_to_opam_packages opam;
  register "seal" [
    main
    $ default_console
    $ stack
    $ dir
    $ default_entropy
    $ default_clock
  ]
