functor AMD64TypesFn (
	structure Spec : TARGET_SPEC
) : ARCH_TYPES = struct

  structure M = CFG
  structure Ty = CFGTy

  val wordSzB = Word.toInt Spec.wordSzB
  val wordAlignB = Word.toInt Spec.wordAlignB

  fun alignedRawTySzB Ty.T_Vec128 = 16
    | alignedRawTySzB _ = wordAlignB
  fun alignedTySzB ty = 
      (case ty
	of M.T_Raw rt => alignedRawTySzB rt
	 | _ => wordAlignB
      (* esac *))

  fun sizeOfRawTyB rt =
      (case rt
	of Ty.T_Byte => 1
	 | Ty.T_Short => 2
	 | Ty.T_Int => 4
	 | Ty.T_Long => 8
	 | Ty.T_Float => 4
	 | Ty.T_Double => 8
	 | Ty.T_Vec128 => 16
      (* escac *))
  fun szOfB ty =
      (case ty
	of M.T_Raw rt => sizeOfRawTyB rt
	 | _ => wordSzB
      (* esac *))
  fun szOf ty = szOfB ty * 8

end (* AMD64TypesFn *)
