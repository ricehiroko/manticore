(* subst-var.sml
 * 
 * COPYRIGHT (c) 2006 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 *)

structure SubstVar =
  struct

    structure A = AST

    fun pat s p = (case p
          of A.TuplePat ps => A.TuplePat (List.map (pat s) ps)
	   | A.VarPat v => A.VarPat (s v)
	   | A.WildPat t => A.WildPat t
	   | A.ConstPat c => A.ConstPat c
          (* end case *))

    fun exp s e = let
	  fun exp (A.LetExp (b, e)) = A.LetExp (binding s b, exp e)
	    | exp (A.IfExp (e1, e2, e3, t)) = A.IfExp (exp e1, exp e2, exp e3, t)
	    | exp (A.CaseExp (e, ms, t)) = A.CaseExp (exp e, List.map (match s) ms, t)
	    | exp (A.PCaseExp (es, pms, t)) = A.PCaseExp (List.map exp es, List.map (pmatch s) pms, t)
	    | exp (A.HandleExp (e, ms, t)) = A.HandleExp (exp e, List.map (match s) ms, t)
	    | exp (A.RaiseExp (e, t)) = A.RaiseExp (exp e, t)
	    | exp (A.FunExp (x, e, t)) = A.FunExp (x, exp e, t)
	    | exp (A.ApplyExp (e1, e2, t)) = A.ApplyExp (exp e1, exp e2, t)
	    | exp (m as A.VarArityOpExp _) = m
	    | exp (A.TupleExp es) = A.TupleExp (List.map exp es)
	    | exp (A.RangeExp (e1, e2, oe3, t)) =
	      A.RangeExp (exp e1, exp e2, Option.map exp oe3, t)
	    | exp (A.PTupleExp es) = A.PTupleExp (List.map exp es)
	    | exp (A.PArrayExp (es, t)) = A.PArrayExp (List.map exp es, t)
	    | exp (A.PCompExp (e, pes, opred)) = 
	      A.PCompExp (exp e, 
			  List.map (fn (p,e) => (pat s p, exp e)) pes,
			  Option.map exp opred)
	    | exp (A.PChoiceExp (es, t)) = A.PChoiceExp (List.map exp es, t)
	    | exp (A.SpawnExp e) = A.SpawnExp (exp e) 
	    | exp (k as A.ConstExp _) = k
	    | exp (A.VarExp (x, ts)) = A.VarExp (s x, ts)
	    | exp (A.SeqExp (e1, e2)) = A.SeqExp (exp e1, exp e2)
	    | exp (ov as A.OverloadExp _) = ov
          in
	     exp e
          end

    and match s (A.PatMatch (p, e)) = A.PatMatch (pat s p, exp s e)
      | match s (A.CondMatch (p, cond, e)) = A.CondMatch (pat s p, exp s cond, exp s e)

    and binding s (A.ValBind (p, e)) = A.ValBind (pat s p, exp s e)
      | binding s (A.PValBind (p, e)) = A.PValBind (pat s p, exp s e)
      | binding _ _ = raise Fail "todo"
			  
    and pmatch s (A.PMatch (ps, e)) = A.PMatch (List.map (ppat s) ps, exp s e)
      | pmatch s (A.Otherwise e) = A.Otherwise (exp s e)

    and ppat s (w as A.NDWildPat _) = w
      | ppat s (A.HandlePat (p, t)) = A.HandlePat (pat s p, t)
      | ppat s (A.Pat p) = A.Pat (pat s p)

  end (* SubstVar *)
