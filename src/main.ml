(*
 * Copyright (c) 2015 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Cmdliner

let verbose =
  let doc = Arg.info ~doc:"Be more verbose." ["v";"verbose"] in
  Arg.(value & flag & doc)

let color =
  let color_tri_state =
    try match Sys.getenv "COLOR" with
      | "always" -> `Always
      | "never"  -> `Never
      | _        -> `Auto
    with
    | Not_found  -> `Auto
  in
  let doc = Arg.info ~docv:"WHEN"
      ~doc:"Colorize the output. $(docv) must be `always', `never' or `auto'."
      ["color"]
  in
  let choices = Arg.enum [ "always", `Always; "never", `Never; "auto", `Auto ] in
  let arg = Arg.(value & opt choices color_tri_state & doc) in
  let to_bool = function
    | `Always -> true
    | `Never  -> false
    | `Auto   -> Unix.isatty Unix.stdout in
  Term.(pure to_bool $ arg)

let directory =
  let doc = Arg.info ~docv:"DIRECTORY"
      ~doc:"Location of the local directory to seal." [] in
  Arg.(required & pos 0 (some string) None & doc)

let key =
  let doc = Arg.info ~docv:"KEY"
      ~doc:"Location of the private key to sign the sealing." [] in
  Arg.(required & pos 0 (some string) None & doc)

let seal verbose color seal_dir key =
  if color then Log.color_on ();
  if verbose then Log.set_log_level Log.DEBUG;
  let (/) = Filename.concat in
  let exec_dir = Filename.get_temp_dir_name () / "mirage-seal" in
  Printf.printf "DIR: %s\n%!" exec_dir;
  (* FIXME: clean exec_seal directory *)
  let () = try Unix.mkdir exec_dir 0o755 with Unix.Unix_error _ -> () in
  (* FIXME: proper real-path *)
  let seal_dir =
    if Filename.is_relative seal_dir then Sys.getcwd () / seal_dir else seal_dir
  in
  let output name =
    match Static.read name with
    | None   -> failwith (name ^ ": file not found")
    | Some f ->
      let oc = open_out (exec_dir / name) in
      output_string oc f;
      close_out oc
  in
  output "dispatch.ml";
  output "config.ml";
  let i =
    Sys.command (Printf.sprintf "cd %s && SEAL_DIR=%s mirage configure"
                   exec_dir seal_dir)
  in
  exit i

let cmd =
  let doc = "Seal a local directory into a Mirage unikernel." in
  let man = [
    `S "AUTHORS";
    `P "Thomas Gazagnaire   <thomas@gazagnaire.org>";

    `S "BUGS";
    `P "Check bug reports at https://github.com/samoht/mirage-seal/issues.";
  ] in
  Term.(ret (pure seal $ verbose $ color $ directory $ key)),
  Term.info "mirage-seal" ~version:Version.current ~doc ~man

let () = match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
