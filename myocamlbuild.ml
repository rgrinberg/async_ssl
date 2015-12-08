(* OASIS_START *)
(* OASIS_STOP *)

let is_osx =
  lazy ("uname" |> Ocamlbuild_plugin.run_and_read |> String.trim = "Darwin")

let homebrew_ssl =
  let path = "/usr/local/opt/openssl/include" in
  lazy (
    if Sys.is_directory path
    then path
    else failwith ("openssl isn't installed in: " ^ path)
  )

let dispatch = function
  | After_rules ->
    let stubgen          = "stubgen/ffi_stubgen.byte" in
    let stubgen_types    = "stubgen/ffi_types_stubgen.byte" in
    let stubgen_ml_types = "stubgen/ffi_ml_types_subgen.exe" in

    rule "generated ml"
      ~dep:stubgen
      ~prod:"src/ffi_generated.ml"
      (fun _ _ ->
         Cmd(S[P stubgen; A"-ml"; Sh">"; A"src/ffi_generated.ml"]));

    rule "generated-types c"
      ~dep:stubgen_types
      ~prod:"stubgen/ffi_ml_types_stubgen.c"
      (fun _ _ ->
         Cmd (S [P stubgen_types; Sh">"; A"stubgen/ffi_ml_types_stubgen.c"]));

    rule "generated-types exe"
      ~dep:"stubgen/ffi_ml_types_stubgen.c"
      ~prod:stubgen_ml_types
      (fun _ _ ->
         let env = BaseEnvLight.load () in
         let cc = BaseEnvLight.var_get "bytecomp_c_compiler" env in
         let stdlib = BaseEnvLight.var_get "standard_library" env in
         let ctypes = BaseEnvLight.var_get "pkg_ctypes" env in
         let args =
           ref [Sh cc; A"stubgen/ffi_ml_types_stubgen.c";
            A"-I"; P ctypes; A"-I"; P stdlib] in
         if Lazy.force is_osx
         then args := !args @ [A"-I"; P (Lazy.force homebrew_ssl)];
         args := !args @ [A"-o"; A stubgen_ml_types];
         Cmd (S !args)
      );

    rule "generated-types ml"
      ~dep:stubgen_ml_types
      ~prod:"src/ffi_generated_types.ml"
      (fun _ _ ->
         Cmd (S [P stubgen_ml_types; Sh">>"; A"src/ffi_generated_types.ml"]));

    rule "generated c"
      ~dep:stubgen
      ~prod:"src/ffi_generated_stubs.c"
      (fun _ _ ->
         Cmd(S[P stubgen; A"-c"; Sh">"; A"src/ffi_generated_stubs.c"]));

    flag ["c"; "compile"] & S[A"-I"; A"src"; A"-package"; A"ctypes"]

  | _ ->
    ()

let () = Ocamlbuild_plugin.dispatch (fun hook -> dispatch hook; dispatch_default hook)
