(*
 * This implementation of the memo table allows the underlying representation
 * to grow in chunks as more items are inserted.
 * The representation consists of a tuple with all of the administrative data
 * and a pointer to the top-level segment array.
 * The segment array starts with just one segment of the data, but will point
 * to each of the individual segments as the table grows. Addressing elements
 * is therefore based on the current size of the table and may require looking
 * down multiple buckets if the table has grown but the bucket has not yet been
 * rebalanced (i.e., the items moved up from prior locations).
 *
 *)

structure DynamicMemoTable =
  struct

  datatype 'a entry = UNINIT | INIT | ENTRY of long * int * 'a

  (* (growth, current elements, array of segments) *)
  type 'a table  = int Array.array * int Array.array * 'a entry Array.array option Array.array

  val maxSegments = 10000
  val maxSize = 18 (* We cannot allocate an array with > 2^18 elements *)
  val threshold = 7 (* 7 = 70% *)
  val buckets = 1 (* TODO: need to change the array.array and some lookups for this to really work at > 1 *)

  fun mkTable () =
      (Array.array (1, 1),
       Array.array (1, 0),
       Array.array (maxSegments, NONE))

  (* The capacity will be one of:
   * 2^10
   * 2^10 + 2^11
   * ...
   * 2^10 +...+ 2^18 + 2^18*i (for i \in 0...\inf)
   *)
  fun capacity i =
      case i
       of 0 => 0
        | 1 => 1024
        | 2 => (1024 + 2048)
        | 3 => (1024 + 2048 + 4096)
        | 4 => (1024 + 2048 + 4096 + 8192)
        | 5 => (1024 + 2048 + 4096 + 8192 + 16384)
        | 6 => (1024 + 2048 + 4096 + 8192 + 16384 + 32768)
        | 7 => (1024 + 2048 + 4096 + 8192 + 16384 + 32768 + 65536)
        | 8 => (1024 + 2048 + 4096 + 8192 + 16384 + 32768 + 65536 + 131072)
        | n => (1024 + 2048 + 4096 + 8192 + 16384 + 32768 + 65536 + 131072 + (262144 * (n-8)))

  fun growIfNeeded (segments, itemCount, allSegments) = let
      val segmentCount = Array.sub (segments, 0)
  in
      if ((capacity (segmentCount) * threshold < (Array.sub (itemCount, 0) * 10))
          andalso segmentCount < maxSegments)
      then (let
               val segmentCount = segmentCount +1
               val new = Array.array ((capacity segmentCount) - (capacity (segmentCount-1)), UNINIT)
               val _ = Array.update (allSegments, segmentCount-1, SOME new)
           in
               Array.update (segments, 0, segmentCount)
           end)
      else ()
  end

  (* returns the segment and segment-relative element index *) 
  fun findSegment i = let
      fun check (s,i) = 
          if (capacity s > i)
          then check (s+1, i)
          else (s, (i - capacity (s-1)))
  in
      check (1, i)
  end

  (*
   * If the bucket is still in the UNINIT state, then this function will attempt to
   * probe the previous-capacity buckets for items that should now be at this location
   * and move them. If there are no such items, the bucket will transition to the INIT
   * state.
   * If this process encounters a bucket at the prior capacity that is also UNINIT,
   * this process needs to continue recursively.
   *)
  fun initBucket (segmentIndex, subIndex, hash, index, segmentCount, allSegments) = let
      val _ = print "K"
      val startIndex = subIndex * buckets
      val _ = print (String.concat[Int.toString segmentIndex, " subindex: ",
                                  Int.toString subIndex, " hash: ",
                                  Int.toString hash, " idnex: ",
                                  Int.toString index, "\n"])
      val SOME(segment) = Array.sub (allSegments, segmentIndex)
      val _ = print "L"
  in
      case Array.sub (segment, startIndex)
       of UNINIT => (
           let
      val _ = print "M"
               val segmentCount' = segmentCount-1
               val index' = hash mod (capacity segmentCount')
               val (segmentIndex', subIndex') = findSegment index'                                        
      val _ = print "N"
               val _ = initBucket (segmentIndex', subIndex', hash, index', segmentCount', allSegments)
               val startIndex' = subIndex' * buckets
               val M' = capacity segmentCount'
      val _ = print "O"
               fun maybeMoveItems (i, next) = (
                   if (i = buckets)
                   then ()
                   else (let
                            val SOME(segment') = Array.sub (allSegments, segmentIndex')
                            val e = Array.sub (segment', startIndex' + i)
      val _ = print "P"
                        in
                            case e
                             of INIT => ()
                              (* BUG: Have to re-create the value because we don't support 'as'
                               *)
                              | ENTRY(t, key', value) => (
                                if (key' mod M' = index)
                                then (Array.update (segment, startIndex+next, ENTRY(t, key', value));
                                      maybeMoveItems (i+1, next+1))
                                else (maybeMoveItems (i+1, next)))
                              | UNINIT => raise Fail "initBucket encountered an uninitialized bucket"
                        end))
           in
               maybeMoveItems (0, 0)
           end)
        | _ => ()
  end

  fun insert ((segments, itemCount, allSegments), key, item) = let
      val _ = print "A"
      val age = Time.now()
      val new = ENTRY (age, key, item)
      val hash = Int.larsonHash key
      val segmentCount = Array.sub (segments, 0)
      val index = hash mod (capacity segmentCount)
      val (segmentIndex, subIndex) = findSegment index
      val _ = initBucket (segmentIndex, subIndex, hash, index, segmentCount, allSegments)

      val _ = print "B"
      val SOME(segment) = Array.sub (allSegments, segmentIndex)
      val startIndex = subIndex * buckets
      val _ = Array.update (itemCount, 0, Array.sub (itemCount, 0) + 1)
      val _ = growIfNeeded (segments, itemCount, allSegments)
      val _ = print "C"
      fun insertEntry (i, oldestTime, oldestOffset) = (
          if i = buckets
          then (Array.update (segment, startIndex + oldestOffset, new))
          else (case Array.sub (segment, startIndex + i)
                 of INIT => (Array.update (segment, startIndex + i, new))
                  | ENTRY (t, _, _) =>
                    if t < oldestTime
                    then insertEntry (i+1, t, i)
                    else insertEntry (i+1, oldestTime, oldestOffset)
                  | UNINIT => raise Fail "insert encountered an uninitialized bucket"))
  in
      insertEntry (0, Int.toLong (Option.valOf Int.maxInt), 0)
  end

  fun find ((segments, itemCount, allSegments), key) = let
(*      val hash = (c * key') mod M *)
      val _ = print "D"
      val age = Time.now()
      val hash = Int.larsonHash key
      val _ = print "G"
      val segmentCount = Array.sub (segments, 0)
      val _ = print "H"
      val index = hash mod (capacity segmentCount)
      val _ = print "I"
      val (segmentIndex, subIndex) = findSegment index
      val _ = print "J"
      val _ = initBucket (segmentIndex, subIndex, hash, index, segmentCount, allSegments)
                         
      val _ = print "E"
      val SOME(segment) = Array.sub (allSegments, segmentIndex)
      val startIndex = subIndex * buckets
      val _ = print "F"
      fun findEntry (i) = (
          if (i = buckets)
          then NONE 
          else (let
                   val e = Array.sub (segment, startIndex + i)
               in
                   case e
                    of INIT => NONE
                     | ENTRY(_, key', value) =>
                       if key' = key
                       then (Array.update (segment, startIndex+i, ENTRY(Time.now(), key', value));
                             SOME value)
                       else (findEntry (i+1))
                     | UNINIT => raise Fail "find encountered an uninitialized bucket"
               end))
  in
      findEntry 0 
  end

  end
