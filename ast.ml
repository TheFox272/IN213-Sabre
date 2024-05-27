exception Move_on ;;
exception Memory ;;
exception Exit ;;

(* Ce fichier contient la définition du type OCaml des arbres de
 * syntaxe abstraite du langage, ainsi qu'un imprimeur des phrases
 * du langage.
*)

type expr =
  | EBool of bool                               (* true, false *)
  | EInt of int                                 (* 1, 2, 3 *)
  | ESymb of string                             (* "pomme" *)
  | EIdent of string                            (* x, toto, fact *)
  | EMonop of (string * expr)                   (* -e *)
  | EBinop of (string * expr * expr)            (* e1 + e2 *)
  | EAffect of (string * expr)                  (* x := e *)
  | ERule of (expr * expr)                        (* if e1 then e2*)
  | EList of (expr * expr)              (* {c1, c2} *)
  | EAsk of (expr)               (* ask(e) *)
;;


(* Note : dans le printf d'OCaml, le format %a
   correspond a 2 arguments consecutifs :
        - une fonction d'impression de type (out_channel -> 'a -> unit)
        - un argument a imprimer, de type 'a
   Voir le cas EApp ci-dessous.
 *)
let rec print oc = function
  | EInt n -> Printf.fprintf oc "%d" n
  | EBool b -> Printf.fprintf oc "%s" (if b then "true" else "false")
  | ESymb s -> Printf.fprintf oc "\"%s\"" s
  | EIdent s -> Printf.fprintf oc "%s" s
  | ERule (test, e) ->
      Printf.fprintf oc "(if %a then %a)" print test print e
  | EList (c1, c2) ->
      Printf.fprintf oc "{%a, %a}" print c1 print c2
  | EAsk (e) ->
      Printf.fprintf oc "ask(%a)" print e
  | EBinop (op,e1,e2) ->
      Printf.fprintf oc "(%a %s %a)" print e1 op print e2
  | EAffect (id,e) ->
      Printf.fprintf oc "%s := %a" id print e
  | EMonop (op,e) ->
      Printf.fprintf oc "(%s%a)" op print e
;;
