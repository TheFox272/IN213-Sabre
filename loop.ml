let version = "1.0" ;;

let usage () =
  let _ =
    Printf.eprintf
      "Usage: %s\n\tEnter the SABRE environment\n%!"
    Sys.argv.(0) in
  let _ =
    Printf.eprintf
      "Usage: %s [file]\n\tRead a SABRE program from file before entering the environment\n%!"
    Sys.argv.(0) in
  exit 1
;;

let main() =
  let input_channel =
    match Array.length Sys.argv with
    | 1 -> stdin
    | 2 -> (
        match Sys.argv.(1) with
        | "-h" | "--help" -> usage ()
        | name ->
            (try (open_in name) with
            |_ -> Printf.eprintf "Opening %s failed\n%!" name; exit 1)
       )
    | n -> usage () in
  let _ = Printf.printf "\n\n        Welcome to SABRE, version %s\n%!\n" version in
  let _ = Printf.printf "Set your rules with \"if <cond1>, <cond2>, ... then <conc1>, <conc2>, ... .\"\n" in
  let _ = Printf.printf "End the set of rules with \"..\"\n" in
  let _ = Printf.printf "See the current state of the system with \"memory\"\n" in
  let _ = Printf.printf "End the session with \"exit\"\n\n" in
  let lexbuf = ref (Lexing.from_channel input_channel) in

  let attributes : Memory.attributes_table = ref [] in
  let rules : Memory.rules_table = ref [] in
  let set = ref true in
  while !set do
    try
      let _ = Printf.printf  "> %!" in
      let e = Parseur.set Lexeur.lex !lexbuf in
      (* à décommenter pour afficher l'arbre abstrait *)
      (* let _ = Printf.printf "Recognized: " in
      let _ = Ast.print stdout e in *)
      let attributes_copy = !attributes in
      let rules_copy = !rules in
      begin
      try
        Sem.compile_rule e attributes rules;
        Printf.printf "Rule accepted.\n"
      with
      | Failure msg ->
          (Printf.printf "Error: %s\nNo attribute/rule added.\n" msg;
          attributes := attributes_copy;
          rules := rules_copy)
      end;
      Printf.printf "\n%!"
    with
    | Lexeur.Eoi -> lexbuf := Lexing.from_channel stdin
    | Failure msg -> Printf.printf "Error: %s\n\n" msg
    (*if the parser raised the error End_of_set, then move on to the next loop*)
    | Ast.Move_on ->
      Printf.printf "\nRules are set.\n\n";
      Printf.printf "State a fact with \"<fact1>, <fact2>, ... !\"\n";
      Printf.printf "Ask a question with \"<question> ?\" or \"& <name> ?\"\n" ;
      Printf.printf "See the current state of the system with \"memory\"\n" ;
      Printf.printf "End the session with \"exit\"\n\n" ;
      set := false
    | Ast.Exit -> Printf.printf "Session aborted.\n%!" ; exit 0
    | Ast.Memory -> Sem.printmem stdout !attributes !rules
    | Invalid_argument e -> Printf.printf "Rule is invalid\n\n"
    | Parsing.Parse_error ->
        let sp = Lexing.lexeme_start_p !lexbuf in
        let ep = Lexing.lexeme_end_p !lexbuf in
        Format.printf
          "File %S, line %i, characters %i-%i: Syntax error.\n"
          sp.Lexing.pos_fname
          sp.Lexing.pos_lnum
          (sp.Lexing.pos_cnum - sp.Lexing.pos_bol)
          (ep.Lexing.pos_cnum - sp.Lexing.pos_bol)
    | Lexeur.LexError (sp, ep) ->
        Printf.printf
          "File %S, line %i, characters %i-%i: Lexical error.\n"
          sp.Lexing.pos_fname
          sp.Lexing.pos_lnum
          (sp.Lexing.pos_cnum - sp.Lexing.pos_bol)
          (ep.Lexing.pos_cnum - sp.Lexing.pos_bol)
  done
;

  let facts : Memory.facts_table = ref [] in
  let associations : Memory.associations_table = ref [] in
  while true do
    try
      let _ = Printf.printf  "> %!" in
      let e = Parseur.use Lexeur.lex !lexbuf in
      (* à décommenter pour afficher l'arbre abstrait *)
      (* let _ = Printf.printf "Recognized: " in
      let _ = Ast.print stdout e in *)
      let attributes_copy = !attributes in
      let rules_copy = !rules in
      let facts_copy = !facts in
      let associations_copy = !associations in
      begin
      try
        Sem.compile_use e attributes rules facts associations;
        Printf.printf "Use validated.\n"
      with
      | Failure msg ->
          (Printf.printf "Error: %s\nUse not validated\n" msg;
          attributes := attributes_copy;
          rules := rules_copy;
          facts := facts_copy;
          associations := associations_copy)
      end;
      Printf.printf "\n%!"
    with
    | Lexeur.Eoi -> lexbuf := Lexing.from_channel stdin
    | Failure msg -> Printf.printf "Error: %s\n\n" msg
    | Invalid_argument e -> Printf.printf "Use is invalid\n\n"
    | Ast.Memory -> Sem.printmem stdout !attributes !rules; Sem.printfacts stdout !facts; Sem.printassociations stdout !associations
    | Ast.Exit -> Printf.printf "See you later !\n%!" ; exit 0
    | Parsing.Parse_error ->
        let sp = Lexing.lexeme_start_p !lexbuf in
        let ep = Lexing.lexeme_end_p !lexbuf in
        Format.printf
          "File %S, line %i, characters %i-%i: Syntax error.\n"
          sp.Lexing.pos_fname
          sp.Lexing.pos_lnum
          (sp.Lexing.pos_cnum - sp.Lexing.pos_bol)
          (ep.Lexing.pos_cnum - sp.Lexing.pos_bol)
    | Lexeur.LexError (sp, ep) ->
        Printf.printf
          "File %S, line %i, characters %i-%i: Lexical error.\n"
          sp.Lexing.pos_fname
          sp.Lexing.pos_lnum
          (sp.Lexing.pos_cnum - sp.Lexing.pos_bol)
          (ep.Lexing.pos_cnum - sp.Lexing.pos_bol)
      
  done
;;

if !Sys.interactive then () else main () ;;
