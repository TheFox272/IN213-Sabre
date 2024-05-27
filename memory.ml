(* Ce fichier contient les types et fonctions utiles pour la mémorisation des données *)

type attr_type = Bool | Int | Symb | Unknown

let string_of_attr_type = function
  | Bool -> "bool"
  | Int -> "int"
  | Symb -> "symb"
  | Unknown -> "unknown"

(* Attribute = id, name, in condition rules, in conclusion rules, type, possible values * askable *)
type attributes_row = int * string * int list * int list * attr_type * Ast.expr list * bool
type attributes_table = attributes_row list ref

(* Find the row of an attribute in the table, and returns it. Returns None if the attribute is not in the table *)
let get_attribute (attributes:attributes_table) (name:string): attributes_row option =
  let rec get_attribute_rec (attributes:attributes_row list) (name:string) : attributes_row option =
    match attributes with
    | [] -> None
    | (id, name_, cond, conc, type_, values, askable)::q -> if name = name_ then Some (id, name_, cond, conc, type_, values, askable) else get_attribute_rec q name
  in
  get_attribute_rec !attributes name

(* Add an attribute to the table *)
let add_attribute (attributes:attributes_table) (name:string) (type_:attr_type) (id_rule:int) (value:Ast.expr list) (askable:bool) : unit =
  let id = List.length !attributes in
  if askable then
    attributes := !attributes @ [(id, name, [id_rule], [], type_, value, askable)]
  else
    attributes := !attributes @ [(id, name, [], [id_rule], type_, value, askable)]
;;

(* Changes an attribute in the table. Only the condition, conclusion and askable fields can be changed *)
let change_attribute (attributes:attributes_table) (id, name, cond, conc, type_, values, askable:attributes_row) : bool =
  let rec change_attribute_rec (attributes:attributes_row list) (id, name, cond, conc, type_, values, askable) =
    match attributes with
    | [] -> raise (Failure "change_attribute: attribute not found")
    | (id_, name_, cond_, conc_, type__, values_, askable_)::q ->
      if id = id_ then
        if name = name_ && type_ = type__ then
          (id, name, cond, conc, type_, values, askable)::q, false
        else if name = name_ && type__ = Unknown then
          (id, name, cond, conc, type_, values, askable)::q, true
        else
          raise (Failure "change_attribute: name or type cannot be changed")
      else
        let q_, changed_type = change_attribute_rec q (id, name, cond, conc, type_, values, askable) in
        (id_, name_, cond_, conc_, type__, values_, askable_)::q_, changed_type
  in
  let new_attributes, changed_type = change_attribute_rec !attributes (id, name, cond, conc, type_, values, askable) in
  attributes := new_attributes;
  changed_type
;;

(* Rule = id, condition, conclusion, triggered *)
type rules_row = int * Ast.expr list * Ast.expr list * bool
type rules_table = rules_row list ref

let get_rules (rules:rules_table) (ids:int list) : rules_row list =
  List.filter (fun (id, _, _, _) -> List.mem id ids) !rules
;;

let change_rule (rules:rules_table) (id, cond, conc, triggered:rules_row) : unit =
  let rec change_rule_rec (rules:rules_row list) (id, cond, conc, triggered) =
    match rules with
    | [] -> raise (Failure "change_rule: rule not found")
    | (id_, cond_, conc_, triggered_)::q ->
      if id = id_ then
        (id, cond, conc, triggered)::q
      else
        (id_, cond_, conc_, triggered_)::change_rule_rec q (id, cond, conc, triggered)
  in
  rules := change_rule_rec !rules (id, cond, conc, triggered)


(* Facts = id, value *)
type facts_row = Ast.expr
type facts_table = facts_row list ref

(* Associations = id_attr_1, id_attr_2 *)
type associations_table = (string * Ast.expr) list ref

let rec get_value (facts:facts_row list) (name:string) : Ast.expr option =
  match facts with
  | [] -> None
  | EAffect (name_, value)::q -> if name = name_ then (Some value) else get_value q name
  | _ -> raise (Failure "get_value: facts table contains a non-fact")
;;

(* Add a fact to the table. Raises an exception if the fact is already in the table. Returns true if name was in to_eval *)
let add_fact (facts:facts_table) (name:string) (value:Ast.expr) (no_msg:bool): unit =
  if get_value !facts name = None then
    facts := (EAffect (name, value)) :: !facts
  else
    if not no_msg then let msg = "add_fact: fact " ^ name ^ " already in the table" in raise (Failure msg)


