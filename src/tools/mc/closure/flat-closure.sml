(* flat-closure.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure FlatClosure : sig

    val convert : CPS.module -> CFG.module

  end = struct

    structure FV = FreeVars
    structure VMap = CPS.Var.Map

  (* convert from CPS types to CFG types *)
    fun cvtTy (CPSTy.T_Any) = CFG.T_Any
      | cvtTy (CPSTy.T_Bool) = CFG.T_Bool
      | cvtTy (CPSTy.T_Raw rTy) = CFGTy.T_Raw rTy
      | cvtTy (CPSTy.T_Wrap rTy) = CFG.T_Wrap rTy
      | cvtTy (CPSTy.T_Tuple tys) = CFG.T_Tuple(List.map cvtTy tys)
      | cvtTy (CPSTy.T_Fun tys) = CFG.T_Any (* ??? *)

  (* assign labels to functions and continuations *)
    local
      val {getFn : CPS.var -> CFG.label, setFn, ...} =
	    CPS.Var.newProp (fn f => raise Fail(concat["labelOf(", CPS.Var.toString f, ")"]))
    in
    fun assignLabels lambda = let
	  fun assignFB (f, _, e) = let
(* FIXME: when are labels exported? *)
		val lab = CFG.Label.new(CPS.Var.nameOf f, CFG.Local, cvtTy(CPS.Var.typeOf f))
		in
		  setFn (f, lab);
		  assignExp e
		end
	  and assignExp (CPS.Let(_, _, e)) = assignExp e
	    | assignExp (CPS.Fun(fbs, e)) = (List.app assignFB fbs; assignExp e)
	    | assignExp (CPS.Cont(fb, e)) = (assignFB fb; assignExp e)
	    | assignExp (CPS.If(_, e1, e2)) = (assignExp e1; assignExp e2)
	    | assignExp (CPS.Switch(_, cases, dflt)) = (
		List.app (assignExp o #2) cases;
		Option.app assignExp dflt)
	    | assignExp _ = ()
	  in
	    assignFB lambda
	  end
    val labelOf = getFn
    end

    datatype loc
      = Local of CFG.var	(* bound in the current function *)
      | Global of int		(* at the ith slot of the current closure *)
      | EnclFun of CFG.var	(* the enclosing function (or one that shares the *)
				(* same closure).  The variable is the ep *)

  (* an envrionment for mapping from CPS variables to CFG variables.  We also
   * track the current closure.
   *)
    datatype env = E of {ep : CFG.var, env : loc VMap.map}

  (* create a new CFG variable for a CPS variable *)
    fun newVar x = CFG.Var.new (
	  CPS.Var.nameOf x,
	  CFG.VK_None,
	  cvtTy(CPS.Var.typeOf x))

  (* create a new environment from a list of free variables *)
    fun newEnv fvs = let
	  fun f (x, (i, env, tys)) = let
		val x' = newVar x
		in
		  (i+1, VMap.insert(env, x, Global i), CFG.Var.typeOf x' :: tys)
		end
	  val (_, env, tys) = List.foldl f (0, VMap.empty, []) fvs
	  val tys = List.rev tys
	  val ep = CFG.Var.new(Atom.atom "ep", CFG.VK_None, CFGTy.T_Tuple tys)
	  in
	    E{ep = ep, env = env}
	  end

    fun newLocals (E{ep, env}, xs) = let
	  fun f (x, (env, xs')) = let
		val x' = newVar x
		in
		  (VMap.insert(env, x, Local x'), x'::xs')
		end
	  val (env, xs) = List.foldl f (env, []) xs
	  in
	    (E{ep=ep, env=env}, List.rev xs)
	  end
 
    fun bindLabel lab = let
	  val labVar = CFG.Var.new(CFG.Label.nameOf lab, CFG.VK_None, CFG.Label.typeOf lab)
	  in
	    (CFG.mkLabel(labVar, lab), labVar)
	  end

    fun findVar (E{env, ...}, x) = VMap.find(env, x)

  (* lookup a variable in the environment; return NONE if it is global, otherwise return
   * SOME of the CFG variable.
   *)
    fun findLocal (E{env, ...}, x) = (case VMap.find(env, x)
	   of NONE => raise Fail("unbound variable " ^ CPS.Var.toString x)
	    | SOME(Local x') => SOME x'
	    | _ => NONE
	  (* end case *))

  (* lookup a CPS variable in the environment.  If it has to be fetched from
   * a closure, we introduce a new temporary for it.
   * QUESTION: should we cache the temp in the environment?
   *)
    fun lookupVar (E{ep, env}, x) = (case VMap.find(env, x)
	   of SOME(Local x') => ([], x')
	    | SOME(Global i) => let (* fetch from closure *)
		val tmp = newVar x
		in
		  ([CFG.mkSelect(tmp, i, ep)], tmp)
		end
	    | SOME(EnclFun ep) => let (* build <ep, cp> pair *)
		val (b, lab) = bindLabel(labelOf x)
		val tmp = CFG.Var.new(
			CPS.Var.nameOf x,
			CFG.VK_None,
			CFGTy.T_Tuple[CFG.Var.typeOf ep, CFG.Var.typeOf lab])
		in
		  ([CFG.mkAlloc(tmp, [ep, lab]), b], tmp)
		end
	    | NONE => raise Fail("unbound variable " ^ CPS.Var.toString x)
	  (* end case *))

    fun lookupVars (env, xs) = let
	  fun lookup ([], binds, xs) = (binds, xs)
	    | lookup (x::xs, binds, xs') = let
		val (b, x) = lookupVar(env, x)
		in
		  lookup (xs, b @ binds, x::xs')
		end
	  in
	    lookup (List.rev xs, [], [])
	  end

    fun convert (m as CPS.MODULE lambda) = let
	  val blocks = ref []
	(* convert an expression to a CFG FUNC; note that this function will convert
	 * any nested functions first.
         *)
	  fun cvtExp (env, lab, conv, e) = let
		fun finish (binds, xfer) = let
		      val func = CFG.mkFunc (lab, conv, List.rev binds, xfer)
		      in
			blocks := func :: !blocks
		      end
		fun cvt (env, e, stms) = (case e
		       of CPS.Let(lhs, rhs, e) => let
			    val (stms', env') = cvtRHS(env, lhs, rhs)
			    in
			      cvt (env', e, stms' @ stms)
			    end
			| CPS.Fun(fbs, e) => (* FIXME *) raise Fail "function binding unimplemented"
			| CPS.Cont(fb, e) => let
			    val (binds, env) = cvtCont(env, fb)
			    in
			      cvt (env, e, binds @ stms)
			    end
			| CPS.If(x, e1, e2) => let
			    val (binds, x) = lookupVar(env, x)
			    fun branch (lab, e) = let
				  val needsEP = ref false
				  fun f (x, (args, params)) = (case findLocal(env, x)
					 of SOME x' => (x' :: args, CFG.Var.copy x' :: params)
					  | NONE => (needsEP := true; (args, params))
					(* end case *))
				  val (args, params) = CPS.Var.Set.foldr f ([], []) (FV.freeVarsOfExp e)
				(* if there are any free globals in e, then we include
				 * the environment pointer as an argument.
				 *)
				  val (args, params) = if !needsEP
					then let val E{ep, ...} = env
					  in (ep :: args, CFG.Var.copy ep :: params) end
					else (args, params)
				  val lab = CFG.Label.new(
					Atom.atom lab,
					CFG.Local,
					CFGTy.T_Code(List.map CFG.Var.typeOf params))
				  in
				    cvtExp (newEnv, lab, CFG.Block params, e);
				    (lab, args)
				  end
			    in
			      finish(binds @ stms,
				CFG.If(x, branch("then", e1), branch("else", e2)))
			    end
			| CPS.Switch(x, cases, dflt) => raise Fail "switch not supported yet"
			| CPS.Apply(f, args) => let
			    val (binds, args) = lookupVars(env, args)
			    val (binds, xfer) = (case args
				   of [arg, ret, exh] => let
					fun bindEP () = let
					      val (binds, f') = lookupVar(env, f)
					      val ep = CFG.Var.new(Atom.atom "ep", CFG.VK_None, CFGTy.T_Any)
					      in
						(CFG.mkSelect(ep, 0, f') :: binds, f', ep)
					      end
					val (cp, ep, binds') = (case CPS.Var.kindOf f
					       of CPS.VK_Fun _ => let
						    val (b, cp) = bindLabel(labelOf f)
						    in
						      case findVar(env, f)
							of SOME(EnclFun ep) => (cp, ep, [b])
							 | _ => let
							    val (binds, _, ep) = bindEP ()
							    in
							      (cp, ep, b::binds)
							    end
						       (* end case *)
						    end
						| _ => let
						    val (binds, f', ep) = bindEP ()
						    val cp = CFG.Var.new(CFG.Var.nameOf f', CFG.VK_None,
							    CFG.T_StdFun{
								clos = CFGTy.T_Any,
								arg = CFG.Var.typeOf arg,
								ret = CFG.Var.typeOf ret,
								exh = CFG.Var.typeOf exh
							      })
						    val b = CFG.mkSelect(cp, 1, f')
						    in
						      (cp, ep, b::binds)
						    end
					      (* end case *))
					val xfer = CFG.StdApply{
						f = cp,
						clos = ep,
						arg = arg,
						ret = ret,
						exh = exh
					      }
					in
					  (binds', xfer)
					end
				    | _ => raise Fail "non-standard calling convention"
				  (* end case *))
			    in
			      finish (binds @ stms, xfer)
			    end
			| CPS.Throw(k, args) => let
			    val (binds, k::args) = lookupVars(env, k::args)
			    val (binds, xfer) = (case args
				   of [arg] => let
(* if k has kind VK_Cont, then we can refer directly to its label *)
					val cp = CFG.Var.new(CFG.Var.nameOf k, CFG.VK_None,
						CFG.T_StdCont{
						    clos = CFG.Var.typeOf k,
						    arg = CFG.Var.typeOf arg
						  })
					val xfer = CFG.StdThrow{
						k = cp,
						clos = k,
						arg = arg
					      }
					in
					  (CFG.mkSelect(cp, 0, k) :: binds, xfer)
					end
				    | _ => raise Fail "non-standard calling convention"
				  (* end case *))
			    in
			      finish (binds @ stms, xfer)
			    end
		      (* end case *))
		in
		  cvt (env, e, [])
		end
	(* convert a CPS RHS to a list of CFG expressions, plus a new environment *)
	  and cvtRHS (env, lhs, rhs) = (case (newLocals(env, lhs), rhs)
		 of ((env, lhs), CPS.Var ys) => let
		      val (binds, ys) = lookupVars (env, ys)
		      in
			(binds @ [CFG.mkVar(lhs, ys)], env)
		      end
		  | ((env, [x]), CPS.Literal lit) => ([CFG.mkLiteral(x, lit)], env)
		  | ((env, [x]), CPS.Select(i, y)) => let
		      val (binds, y) = lookupVar(env, y)
		      in
			(binds @ [CFG.mkSelect(x, i, y)], env)
		      end
		  | ((env, [x]), CPS.Alloc ys) => let
		      val (binds, ys) = lookupVars (env, ys)
		      in
			(binds @ [CFG.mkAlloc(x, ys)], env)
		      end
		  | ((env, [x]), CPS.Wrap y) => let
		      val (binds, y) = lookupVar (env, y)
		      in
			(binds @ [CFG.mkWrap(x, y)], env)
		      end
		  | ((env, [x]), CPS.Unwrap y) => let
		      val (binds, y) = lookupVar (env, y)
		      in
			(binds @ [CFG.mkUnwrap(x, y)], env)
		      end
		  | ((env, [x]), CPS.Prim p) => let
		      val (mkP, args) = PrimUtil.explode p
		      val (binds, args) = lookupVars (env, args)
		      in
			(binds @ [CFG.mkPrim(x, mkP args)], env)
		      end
		  | ((env, [x]), CPS.CCall(f, args)) => let
		      val (binds, f::args) = lookupVars (env, f::args)
		      in
			(binds @ [CFG.mkCCall(x, f, args)], env)
		      end
		(* end case *))
	(* convert a function *)
	  and cvtFun (env, (f, params, e)) = let
		in
		  (CFG.mkAlloc(f', clos) :: binds, env)
		end
	(* convert a bound continuation *)
	  and cvtCont (env, (k, params, e)) = let
		in
		  (CFG.mkAlloc(k', clos) :: binds, env)
		end
	  in
	    FV.analyze m;
	    assignLabels lambda;
	    cvtFun (VMap.empty, lambda);
	    CFG.mkModule(!blocks)
	  end

  end
