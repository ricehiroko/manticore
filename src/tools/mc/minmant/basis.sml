(* basis.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Based on CMSC 22610 Sample code (Winter 2007)
 *)

structure Basis : sig

  (* basis type constructors *)
    val boolTyc		: Types.tycon
    val intTyc		: Types.tycon
    val longTyc		: Types.tycon
    val integerTyc	: Types.tycon
    val floatTyc	: Types.tycon
    val doubleTyc	: Types.tycon
    val charTyc		: Types.tycon
    val runeTyc		: Types.tycon
    val stringTyc	: Types.tycon
    val listTyc		: Types.tycon
    val optionTyc	: Types.tycon
    val parrayTyc	: Types.tycon
    val chanTyc		: Types.tycon
    val ivarTyc		: Types.tycon
    val mvarTyc		: Types.tycon
    val eventTyc	: Types.tycon
    val threadIdTyc	: Types.tycon
    val workQueueTyc    : Types.tycon

  (* basis types *)
    val unitTy		: AST.ty
    val boolTy		: AST.ty
    val intTy		: AST.ty
    val floatTy		: AST.ty
    val stringTy	: AST.ty
    val listTy		: AST.ty -> AST.ty
    val optionTy	: AST.ty -> AST.ty
    val threadIdTy	: AST.ty
    val parrayTy	: AST.ty -> AST.ty
    val eventTy		: AST.ty -> AST.ty

  (* a work queue type (not in surface language) *)
    val workQueueTy     : AST.ty

  (* type classes as lists of types *)
    val IntClass	: AST.ty list
    val FloatClass	: AST.ty list
    val NumClass	: AST.ty list
    val OrderClass	: AST.ty list

  (* constructors *)
    val boolTrue	: AST.dcon
    val boolFalse	: AST.dcon
    val listNil		: AST.dcon
    val listCons	: AST.dcon
    val optionNONE	: AST.dcon
    val optionSOME	: AST.dcon

  (* overloaded operators *)
    val neg : (AST.ty_scheme * AST.var list)

  (* primitive operators *)
    val listAppend	: AST.var
    val stringConcat	: AST.var
    val int_div		: AST.var
    val int_gt		: AST.var
    val int_gte		: AST.var
    val int_lt		: AST.var
    val int_lte		: AST.var
    val int_minus	: AST.var
    val int_mod		: AST.var
    val int_neg		: AST.var
    val int_plus	: AST.var
    val int_times	: AST.var
    val long_div	: AST.var
    val long_gt		: AST.var
    val long_gte	: AST.var
    val long_lt		: AST.var
    val long_lte	: AST.var
    val long_minus	: AST.var
    val long_mod	: AST.var
    val long_neg	: AST.var
    val long_plus	: AST.var
    val long_times	: AST.var
    val integer_div	: AST.var
    val integer_gt	: AST.var
    val integer_gte	: AST.var
    val integer_lt	: AST.var
    val integer_lte	: AST.var
    val integer_minus	: AST.var
    val integer_mod	: AST.var
    val integer_neg	: AST.var
    val integer_plus	: AST.var
    val integer_times	: AST.var
    val float_fdiv	: AST.var
    val float_gt	: AST.var
    val float_gte	: AST.var
    val float_lt	: AST.var
    val float_lte	: AST.var
    val float_minus	: AST.var
    val float_neg	: AST.var
    val float_plus	: AST.var
    val float_times	: AST.var
    val double_fdiv	: AST.var
    val double_gt	: AST.var
    val double_gte	: AST.var
    val double_lt	: AST.var
    val double_lte	: AST.var
    val double_minus	: AST.var
    val double_neg	: AST.var
    val double_plus	: AST.var
    val double_times	: AST.var
    val char_gt		: AST.var
    val char_gte	: AST.var
    val char_lt		: AST.var
    val char_lte	: AST.var
    val rune_gt		: AST.var
    val rune_gte	: AST.var
    val rune_lt		: AST.var
    val rune_lte	: AST.var
    val string_gt	: AST.var
    val string_gte	: AST.var
    val string_lt	: AST.var
    val string_lte	: AST.var

  (* predefined functions *)
    val not		: AST.var
    val sqrtf		: AST.var
    val lnf		: AST.var
    val log2f		: AST.var
    val log10f		: AST.var
    val powf		: AST.var
    val expf		: AST.var
    val sinf		: AST.var
    val cosf		: AST.var
    val tanf		: AST.var
    val itof		: AST.var
    val sqrtd		: AST.var
    val lnd		: AST.var
    val log2d		: AST.var
    val log10d		: AST.var
    val powd		: AST.var
    val expd		: AST.var
    val cosd		: AST.var
    val sind		: AST.var
    val tand		: AST.var
    val itod		: AST.var
    val channel		: AST.var
    val send		: AST.var
    val recv		: AST.var
    val iVar		: AST.var
    val iGet		: AST.var
    val iPut		: AST.var
    val mVar		: AST.var
    val mGet		: AST.var
    val mTake		: AST.var
    val mPut		: AST.var
    val itos		: AST.var
    val ltos		: AST.var
    val ftos		: AST.var
    val dtos		: AST.var
    val print		: AST.var
    val args		: AST.var
    val fail		: AST.var

  (* environments *)
    val lookupOp : Atom.atom -> Env.val_bind
    val te0 : Env.ty_env
    val ve0 : Env.var_env

  end = struct

    nonfix div mod

    local
      structure N = BasisNames
      val --> = AST.FunTy
      fun ** (t1, t2) = AST.TupleTy[t1, t2]
      infix 9 **
      infixr 8 -->
      fun forall mkTy = let
	    val tv = TyVar.new(Atom.atom "'a")
	    in
	      AST.TyScheme([tv], mkTy(AST.VarTy tv))
	    end
      fun monoVar (name, ty) = Var.new(Atom.toString name, ty)
      fun polyVar (name, mkTy) = Var.newPoly(Atom.toString name, forall mkTy)
    in

    val boolTyc = TyCon.newDataTyc (N.bool, [])
    val boolTrue = DataCon.new boolTyc (N.boolTrue, NONE)
    val boolFalse = DataCon.new boolTyc (N.boolFalse, NONE)

    local
	val tv = TyVar.new(Atom.atom "'a")
	val tv' = AST.VarTy tv
    in
    val listTyc = TyCon.newDataTyc (N.list, [tv])
    val listNil = DataCon.new listTyc (N.listNil, NONE)
    val listCons = DataCon.new listTyc
	  (N.listCons, SOME(AST.TupleTy[tv', AST.ConTy([tv'], listTyc)]))
    end (* local *)

    local
	val tv = TyVar.new(Atom.atom "'a")
	val tv' = AST.VarTy tv
    in
    val optionTyc = TyCon.newDataTyc (N.option, [tv])
    val optionNONE = DataCon.new optionTyc (N.optionNONE, NONE)
    val optionSOME = DataCon.new optionTyc (N.optionSOME, SOME(tv'))
    end

    val intTyc = TyCon.newAbsTyc (N.int, 0, true)
    val longTyc = TyCon.newAbsTyc (N.long, 0, true)
    val integerTyc = TyCon.newAbsTyc (N.integer, 0, true)
    val floatTyc = TyCon.newAbsTyc (N.float, 0, true)
    val doubleTyc = TyCon.newAbsTyc (N.double, 0, true)
    val charTyc = TyCon.newAbsTyc (N.char, 0, true)
    val runeTyc = TyCon.newAbsTyc (N.rune, 0, true)
    val stringTyc = TyCon.newAbsTyc (N.string, 0, true)
    val parrayTyc = TyCon.newAbsTyc (N.parray, 1, false)
    val chanTyc = TyCon.newAbsTyc (N.chan, 1, true)
    val ivarTyc = TyCon.newAbsTyc (N.ivar, 1, true)
    val mvarTyc = TyCon.newAbsTyc (N.mvar, 1, true)
    val eventTyc = TyCon.newAbsTyc (N.event, 1, false)
    val threadIdTyc = TyCon.newAbsTyc (N.thread_id, 0, true)
    val workQueueTyc =  TyCon.newAbsTyc (Atom.atom "work_queue", 0, false)

  (* a type for work queues (not part of surface language) *)
    val workQueueTy = AST.ConTy ([], workQueueTyc)

  (* sequential-language predefined types *)
    val unitTy = AST.TupleTy[]
    val boolTy = AST.ConTy([], boolTyc)
    val intTy = AST.ConTy([], intTyc)
    val longTy = AST.ConTy([], longTyc)
    val integerTy = AST.ConTy([], integerTyc)
    val floatTy = AST.ConTy([], floatTyc)
    val doubleTy = AST.ConTy([], doubleTyc)
    val charTy = AST.ConTy([], charTyc)
    val runeTy = AST.ConTy([], runeTyc)
    val stringTy = AST.ConTy([], stringTyc)
    fun listTy ty = AST.ConTy([ty], listTyc)
    fun optionTy ty = AST.ConTy([ty], optionTyc)

  (* concurrent and parallel-language predefined types *)
    val threadIdTy = AST.ConTy([], threadIdTyc)
    fun parrayTy ty = AST.ConTy([ty], parrayTyc)
    fun chanTy ty = AST.ConTy([ty], chanTyc)
    fun ivarTy ty = AST.ConTy([ty], ivarTyc)
    fun mvarTy ty = AST.ConTy([ty], mvarTyc)
    fun eventTy ty = AST.ConTy([ty], eventTyc)

  (* type classes as lists of types *)
    val IntClass = [intTy, longTy, integerTy]
    val FloatClass = [floatTy, doubleTy]
    val NumClass = IntClass @ FloatClass
    val OrderClass = NumClass @ [charTy, runeTy, stringTy]

  (* operator symbols *) 
    val listAppend =	Var.newPoly(Atom.toString N.append,
			  forall(fn tv => let
			    val ty = listTy tv
			    in
			      ty ** ty --> ty
			    end))
    val stringConcat =	monoVar(N.concat, stringTy ** stringTy --> stringTy)

    val int_div =       monoVar(N.div, intTy ** intTy --> intTy)
    val int_gt =        monoVar(N.gt, intTy ** intTy --> boolTy)
    val int_gte =       monoVar(N.gte, intTy ** intTy --> boolTy)
    val int_lt =        monoVar(N.lt, intTy ** intTy --> boolTy)
    val int_lte =       monoVar(N.lte, intTy ** intTy --> boolTy)
    val int_minus =     monoVar(N.minus, intTy ** intTy --> intTy)
    val int_mod =       monoVar(N.mod, intTy ** intTy --> intTy)
    val int_neg =       monoVar(N.uMinus, intTy --> intTy)
    val int_plus =      monoVar(N.plus, intTy ** intTy --> intTy)
    val int_times =     monoVar(N.times, intTy ** intTy --> intTy)

    val long_div =      monoVar(N.div, longTy ** longTy --> longTy)
    val long_gt =       monoVar(N.gt, longTy ** longTy --> boolTy)
    val long_gte =      monoVar(N.gte, longTy ** longTy --> boolTy)
    val long_lt =       monoVar(N.lt, longTy ** longTy --> boolTy)
    val long_lte =      monoVar(N.lte, longTy ** longTy --> boolTy)
    val long_minus =    monoVar(N.minus, longTy ** longTy --> longTy)
    val long_mod =      monoVar(N.mod, longTy ** longTy --> longTy)
    val long_neg =      monoVar(N.uMinus, longTy --> longTy)
    val long_plus =     monoVar(N.plus, longTy ** longTy --> longTy)
    val long_times =    monoVar(N.times, longTy ** longTy --> longTy)

    val integer_div =   monoVar(N.div, integerTy ** integerTy --> integerTy)
    val integer_gt =    monoVar(N.gt, integerTy ** integerTy --> boolTy)
    val integer_gte =   monoVar(N.gte, integerTy ** integerTy --> boolTy)
    val integer_lt =    monoVar(N.lt, integerTy ** integerTy --> boolTy)
    val integer_lte =   monoVar(N.lte, integerTy ** integerTy --> boolTy)
    val integer_minus = monoVar(N.minus, integerTy ** integerTy --> integerTy)
    val integer_mod =   monoVar(N.mod, integerTy ** integerTy --> integerTy)
    val integer_neg =   monoVar(N.uMinus, integerTy --> integerTy)
    val integer_plus =  monoVar(N.plus, integerTy ** integerTy --> integerTy)
    val integer_times = monoVar(N.times, integerTy ** integerTy --> integerTy)

    val float_fdiv =    monoVar(N.fdiv, floatTy ** floatTy --> floatTy)
    val float_gt =      monoVar(N.gt, floatTy ** floatTy --> boolTy)
    val float_gte =     monoVar(N.gte, floatTy ** floatTy --> boolTy)
    val float_lt =      monoVar(N.lt, floatTy ** floatTy --> boolTy)
    val float_lte =     monoVar(N.lte, floatTy ** floatTy --> boolTy)
    val float_minus =   monoVar(N.minus, floatTy ** floatTy --> floatTy)
    val float_neg =	monoVar(N.uMinus, floatTy --> floatTy)
    val float_plus =    monoVar(N.plus, floatTy ** floatTy --> floatTy)
    val float_times =   monoVar(N.times, floatTy ** floatTy --> floatTy)

    val double_fdiv =   monoVar(N.fdiv, doubleTy ** doubleTy --> doubleTy)
    val double_gt =     monoVar(N.gt, doubleTy ** doubleTy --> boolTy)
    val double_gte =    monoVar(N.gte, doubleTy ** doubleTy --> boolTy)
    val double_lt =     monoVar(N.lt, doubleTy ** doubleTy --> boolTy)
    val double_lte =    monoVar(N.lte, doubleTy ** doubleTy --> boolTy)
    val double_minus =  monoVar(N.minus, doubleTy ** doubleTy --> doubleTy)
    val double_neg =    monoVar(N.uMinus, doubleTy --> doubleTy)
    val double_plus =   monoVar(N.plus, doubleTy ** doubleTy --> doubleTy)
    val double_times =  monoVar(N.times, doubleTy ** doubleTy --> doubleTy)

    val char_gt =       monoVar(N.gt, charTy ** charTy --> boolTy)
    val char_gte =      monoVar(N.gte, charTy ** charTy --> boolTy)
    val char_lt =       monoVar(N.lt, charTy ** charTy --> boolTy)
    val char_lte =      monoVar(N.lte, charTy ** charTy --> boolTy)

    val rune_gt =       monoVar(N.gt, runeTy ** runeTy --> boolTy)
    val rune_gte =      monoVar(N.gte, runeTy ** runeTy --> boolTy)
    val rune_lt =       monoVar(N.lt, runeTy ** runeTy --> boolTy)
    val rune_lte =      monoVar(N.lte, runeTy ** runeTy --> boolTy)

    val string_gt =     monoVar(N.gt, stringTy ** stringTy --> boolTy)
    val string_gte =    monoVar(N.gte, stringTy ** stringTy --> boolTy)
    val string_lt =     monoVar(N.lt, stringTy ** stringTy --> boolTy)
    val string_lte =    monoVar(N.lte, stringTy ** stringTy --> boolTy)

(* TODO do @, ! *)

(* TODO what's up with the equality operators?
    val boolEq =	monoVar(N.eq, boolTy ** boolTy --> boolTy)
    val intEq =		monoVar(N.eq, intTy ** intTy --> boolTy)
    val stringEq =	monoVar(N.eq, stringTy ** stringTy --> boolTy)
*)

  (* create a type scheme that binds a kinded type variable *)
    fun tyScheme (cls, mk) = let
	  val tv = TyVar.newClass (Atom.atom "'a", cls)
	  in
	    Types.TyScheme([tv], mk(Types.VarTy tv))
	  end

    val lte = (tyScheme(Types.Order, fn tv => (tv ** tv --> boolTy)),
	       [int_lte, long_lte, integer_lte, float_lte, double_lte, char_lte, rune_lte, string_lte])
    val lt = (tyScheme(Types.Order, fn tv => (tv ** tv --> boolTy)),
	       [int_lt, long_lt, integer_lt, float_lt, double_lt, char_lt, rune_lt, string_lt])
    val gte = (tyScheme(Types.Order, fn tv => (tv ** tv --> boolTy)),
	       [int_gte, long_gte, integer_gte, float_gte, double_gte, char_gte, rune_gte, string_gte])
    val gt = (tyScheme(Types.Order, fn tv => (tv ** tv --> boolTy)),
	       [int_gt, long_gt, integer_gt, float_gt, double_gt, char_gt, rune_gt, string_gt])

    val plus = (tyScheme(Types.Num, fn tv => (tv ** tv --> tv)),
	       [int_plus, long_plus, integer_plus, float_plus, double_plus])
    val minus = (tyScheme(Types.Num, fn tv => (tv ** tv --> tv)),
	       [int_minus, long_minus, integer_minus, float_minus, double_minus])
    val times = (tyScheme(Types.Num, fn tv => (tv ** tv --> tv)),
	       [int_times, long_times, integer_times, float_times, double_times])

    val fdiv = (tyScheme(Types.Float, fn tv => (tv ** tv --> tv)),
		[float_fdiv, double_fdiv])

    val div = (tyScheme(Types.Int, fn tv => (tv ** tv --> tv)),
	       [int_div, long_div, integer_div])
    val mod = (tyScheme(Types.Int, fn tv => (tv ** tv --> tv)),
	       [int_mod, long_mod, integer_mod])

    val neg = (tyScheme(Types.Num, fn tv => (tv --> tv)),
		[int_neg, long_neg, integer_neg, float_neg, double_neg])

    val lookupOp = let
	  val tbl = AtomTable.mkTable (16, Fail "lookupOp")
	  fun ins (id, info) = AtomTable.insert tbl (id, Env.Overload info)
	  in
	  (* insert constructors *)
	    List.app (AtomTable.insert tbl) [
		(N.listCons,	Env.Con listCons)
	      ];
	  (* insert non-overloaded operators *)
	    List.app (AtomTable.insert tbl) [
		(N.append,	Env.Var listAppend),
		(N.concat,	Env.Var stringConcat)
	      ];
	  (* insert overloaded operators *)
	    List.app ins [
		(N.lte,		lte),
		(N.lt,		lt),
		(N.gte,		gte),
		(N.gt,		gt),
		(N.plus,	plus),
		(N.minus,	minus),
		(N.times,	times),
		(N.fdiv,	fdiv),
		(N.div,		div),
		(N.mod,		mod)
	      ];
	    AtomTable.lookup tbl
	  end


  (* predefined functions *)
    val not =		monoVar(N.not, boolTy --> boolTy)
    val sqrtf =		monoVar(N.sqrtf, floatTy --> floatTy)
    val lnf =		monoVar(N.lnf, floatTy --> floatTy)
    val log2f =		monoVar(N.log2f, floatTy --> floatTy)
    val log10f =	monoVar(N.log10f, floatTy --> floatTy)
    val powf =		monoVar(N.powf, floatTy ** floatTy --> floatTy)
    val expf =		monoVar(N.expf, floatTy --> floatTy)
    val sinf =		monoVar(N.sinf, floatTy --> floatTy)
    val cosf =		monoVar(N.cosf, floatTy --> floatTy)
    val tanf =		monoVar(N.tanf, floatTy --> floatTy)
    val itof =		monoVar(N.itof, intTy --> floatTy)
    val sqrtd =		monoVar(N.sqrtd, doubleTy --> doubleTy)
    val lnd =		monoVar(N.lnd, doubleTy --> doubleTy)
    val log2d =		monoVar(N.log2d, doubleTy --> doubleTy)
    val log10d =	monoVar(N.log10d, doubleTy --> doubleTy)
    val powd =		monoVar(N.powd, doubleTy ** doubleTy --> doubleTy)
    val expd =		monoVar(N.expd, doubleTy --> doubleTy)
    val cosd =		monoVar(N.cosd, doubleTy --> doubleTy)
    val sind =		monoVar(N.sind, doubleTy --> doubleTy)
    val tand =		monoVar(N.tand, doubleTy --> doubleTy)
    val itod =		monoVar(N.itod, intTy --> doubleTy)
    val channel =	polyVar(N.channel, fn tv => unitTy --> chanTy tv)
    val send =		polyVar(N.send, fn tv => chanTy tv ** tv --> unitTy)
    val sendEvt =	polyVar(N.sendEvt, fn tv => chanTy tv ** tv --> eventTy unitTy)
    val recv =		polyVar(N.recv, fn tv => chanTy tv --> tv)
    val recvEvt =	polyVar(N.recvEvt, fn tv => chanTy tv --> eventTy tv)
    val wrap =		let
			val a' = TyVar.new(Atom.atom "'a")
			val b' = TyVar.new(Atom.atom "'b")
			in
			  Var.newPoly(Atom.toString N.wrap, 
			    AST.TyScheme([a',b'],
			      (eventTy(AST.VarTy a') ** (AST.VarTy a' --> AST.VarTy b'))
				--> eventTy(AST.VarTy b')))
			end
    val choose =	polyVar(N.choose, fn tv => listTy(eventTy tv) --> eventTy tv)
    val never =		polyVar(N.never, fn tv => eventTy tv)
    val sync =		polyVar(N.sync, fn tv => eventTy tv --> tv)
    val iVar =		polyVar(N.iVar, fn tv => unitTy --> ivarTy tv)
    val iGet =		polyVar(N.iGet, fn tv => ivarTy tv --> tv)
    val iPut =		polyVar(N.iPut, fn tv => (ivarTy tv ** tv) --> unitTy)
    val mVar =		polyVar(N.mVar, fn tv => unitTy --> mvarTy tv)
    val mGet =		polyVar(N.mGet, fn tv => mvarTy tv --> tv)
    val mTake =		polyVar(N.mTake, fn tv => mvarTy tv --> tv)
    val mPut =		polyVar(N.mPut, fn tv => (mvarTy tv ** tv) --> unitTy)
    val itos =		monoVar(N.itos, intTy --> stringTy)
    val ltos =		monoVar(N.ltos, longTy --> stringTy)
    val ftos =		monoVar(N.ftos, floatTy --> stringTy)
    val dtos =		monoVar(N.dtos, doubleTy --> stringTy)
    val print =		monoVar(N.print, stringTy --> unitTy)
    val args =		monoVar(N.args, unitTy --> listTy stringTy)
    val fail =		polyVar(N.fail, fn tv => stringTy --> tv)

(*
    val size =		monoVar(N.size, stringTy --> intTy)
    val sub =		monoVar(N.sub, stringTy ** intTy --> intTy)
    val substring =	monoVar(N.substring, AST.TupleTy[stringTy, intTy, intTy] --> stringTy)
    val concat =	monoVar(N.concat, listTy stringTy --> stringTy)
*)

  (* the predefined type environment *)
    val te0 = Env.fromList [
	    (N.unit,		Env.TyDef(Types.TyScheme([], unitTy))),
	    (N.bool,		Env.TyCon boolTyc),
	    (N.int,		Env.TyCon intTyc),
	    (N.long,		Env.TyCon longTyc),
	    (N.integer,		Env.TyCon integerTyc),
	    (N.float,		Env.TyCon floatTyc),
	    (N.double,		Env.TyCon doubleTyc),
	    (N.char,		Env.TyCon charTyc),
	    (N.rune,		Env.TyCon runeTyc),
	    (N.string,		Env.TyCon stringTyc),
	    (N.list,		Env.TyCon listTyc),
	    (N.option,		Env.TyCon optionTyc),
	    (N.thread_id,	Env.TyCon threadIdTyc),
	    (N.parray,		Env.TyCon parrayTyc),
	    (N.chan,		Env.TyCon chanTyc),
	    (N.ivar,		Env.TyCon ivarTyc),
	    (N.mvar,		Env.TyCon mvarTyc),
	    (N.event,		Env.TyCon eventTyc)
	  ]

    val ve0 = Env.fromList [
	    (N.boolTrue,	Env.Con boolTrue),
	    (N.boolFalse,	Env.Con boolFalse),
	    (N.listNil,		Env.Con listNil),
	    (N.listCons,	Env.Con listCons),
	    (N.optionNONE,	Env.Con optionNONE),
	    (N.optionSOME,	Env.Con optionSOME),
	    (* Unary minus is overloaded, so it's being handled
             * specially by the typechecker *)
	    (N.not,		Env.Var not),
	    (N.sqrtf,		Env.Var sqrtf),
	    (N.lnf,		Env.Var lnf),
	    (N.log2f,		Env.Var log2f),
	    (N.log10f,		Env.Var log10f),
	    (N.powf,		Env.Var powf),
	    (N.expf,		Env.Var expf),
	    (N.sinf,		Env.Var sinf),
	    (N.cosf,		Env.Var cosf),
	    (N.tanf,		Env.Var tanf),
	    (N.itof,		Env.Var itof),
	    (N.sqrtd,		Env.Var sqrtd),
	    (N.lnd,		Env.Var lnd),
	    (N.log2d,		Env.Var log2d),
	    (N.log10d,		Env.Var log10d),
	    (N.powd,		Env.Var powd),
	    (N.expd,		Env.Var expd),
	    (N.sind,		Env.Var sind),
	    (N.cosd,		Env.Var cosd),
	    (N.tand,		Env.Var tand),
	    (N.itod,		Env.Var itod),
	    (N.channel,		Env.Var channel),
	    (N.send,		Env.Var send),
	    (N.recv,		Env.Var recv),
	    (N.iVar,		Env.Var iVar),
	    (N.iGet,		Env.Var iGet),
	    (N.iPut,		Env.Var iPut),
	    (N.mVar,		Env.Var mVar),
	    (N.mGet,		Env.Var mGet),
	    (N.mTake,		Env.Var mTake),
	    (N.mPut,		Env.Var mPut),
	    (N.itos,		Env.Var itos),
	    (N.ltos,		Env.Var ltos),
	    (N.ftos,		Env.Var ftos),
	    (N.dtos,		Env.Var dtos),
	    (N.print,		Env.Var print),
	    (N.args,		Env.Var args),
	    (N.fail,		Env.Var fail)
(*
	    (N.size,		Env.Var size),
	    (N.sub,		Env.Var sub),
	    (N.substring,	Env.Var substring),
	    (N.concat,		Env.Var concat),
*)
	  ]

    end (* local *)

  end
