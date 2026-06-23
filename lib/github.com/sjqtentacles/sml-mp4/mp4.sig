signature MP4 =
sig
  datatype box = Box of { kind : string, size : int, children : box list }
  val parse : Word8Vector.vector -> box list
end
