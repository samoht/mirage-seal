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

(* zone file *)

let data =
  get_path "DATA" (fun dir ->
      if Sys.file_exists dir && Sys.is_directory dir then dir
      else err "%s is not a valid directory." dir
    )
  |> crunch

(* main app *)

let dns =
  foreign "Dispatch.DNS"
    (console @-> kv_ro @-> stackv4 @-> job)

let () =
  let ocamlfind = [
    "dns.lwt-core"
  ] in
  let opam = ["dns"] in
  add_to_ocamlfind_libraries ocamlfind;
  add_to_opam_packages opam;
  register "seal-dns" [
    dns
    $ default_console
    $ data
    $ stack
  ]
