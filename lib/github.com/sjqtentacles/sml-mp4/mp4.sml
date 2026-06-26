structure Mp4 :> MP4 =
struct
  datatype box = Box of { kind : string, size : int, children : box list }

  fun byte (v,i) = Word8.toInt (Word8Vector.sub (v,i))

  fun u32 (v,i) =
    byte (v,i)*16777216 + byte (v,i+1)*65536 + byte (v,i+2)*256 + byte (v,i+3)

  (* 64-bit big-endian read; built from two u32 halves to avoid overflow on
     platforms with a narrow default int. The high word is scaled by 2^32 via
     repeated 2^16 multiplies (so no >2^31 literal is needed). *)
  fun u64 (v,i) =
    let val hi = u32 (v, i)
        val lo = u32 (v, i+4)
    in hi * 65536 * 65536 + lo end

  fun kind (v,i) = String.implode (List.tabulate (4, fn j => Char.chr (byte (v,i+j))))

  val containers =
    ["moov","trak","mdia","minf","stbl","udta","dinf","edts","mvex","moof","traf"]

  fun isContainer k = List.exists (fn c => c = k) containers

  (* Parse the box at `off`; returns (box, nextOffset) or NONE if truncated.
     Handles 32-bit size, size=1 (64-bit largesize), and recurses into known
     container boxes. *)
  fun parseBox (v, off, limit) =
    if off + 8 > limit then NONE
    else
      let
        val sz32 = u32 (v, off)
        val k = kind (v, off + 4)
        (* header length and effective box size *)
        val (headerLen, sz) =
          if sz32 = 1 then
            if off + 16 > limit then (8, sz32)   (* truncated largesize *)
            else (16, u64 (v, off + 8))
          else (8, sz32)
        (* box-0 ("to end of file") and degenerate sizes clamp to the limit *)
        val effSize = if sz = 0 then limit - off
                      else if sz < headerLen then headerLen
                      else sz
        val endOff = off + effSize
        val endClamped = if endOff > limit then limit else endOff
        val children =
          if isContainer k andalso off + headerLen < endClamped
          then parseRange (v, off + headerLen, endClamped)
          else []
      in
        SOME (Box { kind = k, size = sz, children = children }, endClamped)
      end

  and parseRange (v, start, limit) =
    let fun loop (off, acc) =
          if off + 8 > limit then List.rev acc
          else case parseBox (v, off, limit) of
                   NONE => List.rev acc
                 | SOME (b, n) => if n <= off then List.rev acc  (* no progress guard *)
                                  else loop (n, b :: acc)
    in loop (start, []) end

  fun parse v = parseRange (v, 0, Word8Vector.length v)

  fun findAll target boxes =
    List.concat
      (List.map (fn (b as Box { kind, children, ... }) =>
                    (if kind = target then [b] else []) @ findAll target children)
                boxes)
end
