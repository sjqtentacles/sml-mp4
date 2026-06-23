structure Mp4 :> MP4 =
struct
  datatype box = Box of { kind : string, size : int, children : box list }
  fun byte (v,i) = Word8.toInt (Word8Vector.sub (v,i))
  fun u32 (v,i) =
    byte (v,i)*16777216 + byte (v,i+1)*65536 + byte (v,i+2)*256 + byte (v,i+3)
  fun kind (v,i) = String.implode (List.tabulate (4, fn j => Char.chr (byte (v,i+j))))
  fun parseBox (v,off,len) =
    if off + 8 > len then NONE
    else
      let val sz = u32 (v,off)
          val k = kind (v, off + 4)
          val endOff = if sz <= 8 then off + 8 else off + sz
      in SOME (Box { kind = k, size = sz, children = [] }, endOff) end
  fun parse v =
    let fun loop (off,acc) =
          if off + 8 > Word8Vector.length v then List.rev acc
          else case parseBox (v,off,Word8Vector.length v) of
              NONE => List.rev acc | SOME (b,n) => loop (n, b::acc)
    in loop (0,[]) end
end
