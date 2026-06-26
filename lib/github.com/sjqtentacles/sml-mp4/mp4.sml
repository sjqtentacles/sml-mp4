structure Mp4 :> MP4 =
struct
  datatype box = Box of
    { kind : string
    , size : int
    , offset : int
    , dataOffset : int
    , children : box list }

  fun kind       (Box b) = #kind b
  fun size       (Box b) = #size b
  fun offset     (Box b) = #offset b
  fun dataOffset (Box b) = #dataOffset b
  fun children   (Box b) = #children b
  fun payloadLength (Box b) = #size b - (#dataOffset b - #offset b)

  fun byte (v,i) = Word8.toInt (Word8Vector.sub (v,i))

  fun u16 (v,i) = byte (v,i)*256 + byte (v,i+1)

  fun u32 (v,i) =
    byte (v,i)*16777216 + byte (v,i+1)*65536 + byte (v,i+2)*256 + byte (v,i+3)

  fun u64 (v,i) =
    let val hi = u32 (v, i)
        val lo = u32 (v, i+4)
    in hi * 65536 * 65536 + lo end

  fun kindAt (v,i) = String.implode (List.tabulate (4, fn j => Char.chr (byte (v,i+j))))

  val containers =
    ["moov","trak","mdia","minf","stbl","udta","dinf","edts","mvex","moof","traf"]

  fun isContainer k = List.exists (fn c => c = k) containers

  fun parseBox (v, off, limit) =
    if off + 8 > limit then NONE
    else
      let
        val sz32 = u32 (v, off)
        val k = kindAt (v, off + 4)
        val (headerLen, sz) =
          if sz32 = 1 then
            if off + 16 > limit then (8, sz32)
            else (16, u64 (v, off + 8))
          else (8, sz32)
        val effSize = if sz = 0 then limit - off
                      else if sz < headerLen then headerLen
                      else sz
        val endOff = off + effSize
        val endClamped = if endOff > limit then limit else endOff
        val dataOff = off + headerLen
        val children =
          if isContainer k andalso dataOff < endClamped
          then parseRange (v, dataOff, endClamped)
          else []
      in
        SOME (Box { kind = k, size = sz, offset = off
                  , dataOffset = dataOff, children = children }, endClamped)
      end

  and parseRange (v, start, limit) =
    let fun loop (off, acc) =
          if off + 8 > limit then List.rev acc
          else case parseBox (v, off, limit) of
                   NONE => List.rev acc
                 | SOME (b, n) => if n <= off then List.rev acc
                                  else loop (n, b :: acc)
    in loop (start, []) end

  fun parse v = parseRange (v, 0, Word8Vector.length v)

  fun findAll target boxes =
    List.concat
      (List.map (fn (b as Box { kind, children, ... }) =>
                    (if kind = target then [b] else []) @ findAll target children)
                boxes)

  fun find target boxes =
    case findAll target boxes of [] => NONE | b :: _ => SOME b

  fun path [] _ = NONE
    | path [k] boxes = find k boxes
    | path (k :: ks) boxes =
        (case List.find (fn Box b => #kind b = k) boxes of
             NONE => NONE
           | SOME (Box b) => path ks (#children b))

  fun payload v (Box b) =
    let
      val start = #dataOffset b
      val len0 = #size b - (#dataOffset b - #offset b)
      val avail = Word8Vector.length v - start
      val len = Int.max (0, Int.min (len0, avail))
    in
      Word8VectorSlice.vector (Word8VectorSlice.slice (v, start, SOME len))
    end

  (* ---- typed box parsing; offsets are relative to the file vector ---- *)

  fun ftyp v (Box b) =
    if #kind b <> "ftyp" then NONE
    else
      let
        val d = #dataOffset b
        val total = #size b - (d - #offset b)
        val avail = Word8Vector.length v - d
        val len = Int.min (total, avail)
      in
        if len < 8 then NONE
        else
          let
            val major = kindAt (v, d)
            val minor = u32 (v, d + 4)
            val nBrands = (len - 8) div 4
            val compat = List.tabulate (nBrands, fn i => kindAt (v, d + 8 + i*4))
          in
            SOME { major = major, minor = minor, compatible = compat }
          end
      end

  fun fullBox v (Box b) =
    let val d = #dataOffset b
    in { version = byte (v, d), flags = byte (v, d+1)*65536 + byte (v, d+2)*256 + byte (v, d+3) } end

  (* mvhd payload after the 4-byte FullBox header:
     v0: creation(4) modification(4) timescale(4) duration(4)
     v1: creation(8) modification(8) timescale(4) duration(8) *)
  fun mvhd v (Box b) =
    if #kind b <> "mvhd" then NONE
    else
      let
        val d = #dataOffset b
        val version = byte (v, d)
      in
        if version = 1 then
          SOME { timescale = u32 (v, d + 4 + 16), duration = u64 (v, d + 4 + 20) }
        else
          SOME { timescale = u32 (v, d + 4 + 8), duration = u32 (v, d + 4 + 12) }
      end

  (* tkhd: after FullBox header:
     v0: creation(4) modification(4) trackId(4) reserved(4) duration(4)
     v1: creation(8) modification(8) trackId(4) reserved(4) duration(8) *)
  fun tkhd v (Box b) =
    if #kind b <> "tkhd" then NONE
    else
      let
        val d = #dataOffset b
        val version = byte (v, d)
      in
        if version = 1 then
          SOME { trackId = u32 (v, d + 4 + 16), duration = u64 (v, d + 4 + 24) }
        else
          SOME { trackId = u32 (v, d + 4 + 8), duration = u32 (v, d + 4 + 16) }
      end

  (* mdhd: after FullBox header:
     v0: creation(4) modification(4) timescale(4) duration(4)
     v1: creation(8) modification(8) timescale(4) duration(8) *)
  fun mdhd v (Box b) =
    if #kind b <> "mdhd" then NONE
    else
      let
        val d = #dataOffset b
        val version = byte (v, d)
      in
        if version = 1 then
          SOME { timescale = u32 (v, d + 4 + 16), duration = u64 (v, d + 4 + 20) }
        else
          SOME { timescale = u32 (v, d + 4 + 8), duration = u32 (v, d + 4 + 12) }
      end

  fun movieDuration v boxes =
    case path ["moov","mvhd"] boxes of
        NONE => NONE
      | SOME box =>
          (case mvhd v box of
               NONE => NONE
             | SOME { timescale, duration } =>
                 if timescale = 0 then NONE
                 else SOME (real duration / real timescale))

  fun toString boxes =
    let
      fun indent 0 = "" | indent n = "  " ^ indent (n-1)
      fun go depth (Box b) =
        indent depth ^ #kind b ^ " (size=" ^ Int.toString (#size b)
        ^ ", off=" ^ Int.toString (#offset b) ^ ")\n"
        ^ String.concat (List.map (go (depth+1)) (#children b))
    in
      String.concat (List.map (go 0) boxes)
    end
end
