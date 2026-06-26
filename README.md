# sml-mp4

[![CI](https://github.com/sjqtentacles/sml-mp4/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-mp4/actions/workflows/ci.yml)

ISO Base Media File Format (MP4 / `.mov`) **box tree** parsing for Standard ML.
Reads the box list — each box's 4-character type and size — from a byte vector,
recursing into known container boxes and decoding 64-bit large sizes.

## API

```sml
datatype box = Box of { kind : string, size : int, children : box list }

val parse       : Word8Vector.vector -> box list   (* recursive box tree *)
val isContainer : string -> bool
val findAll     : string -> box list -> box list    (* depth-first, pre-order *)
```

```sml
val boxes = Mp4.parse data
List.map (fn Mp4.Box b => #kind b) boxes   (* e.g. ["ftyp", "moov", "mdat"] *)

(* Container boxes are descended into; leaves have children = [] *)
Mp4.isContainer "moov"    (* true  *)
Mp4.isContainer "mvhd"    (* false *)

(* Find every box of a kind anywhere in the tree *)
Mp4.findAll "trak" (Mp4.parse data)   (* all track boxes, however deeply nested *)
```

Recognized container boxes (descended into): `moov`, `trak`, `mdia`, `minf`,
`stbl`, `udta`, `dinf`, `edts`, `mvex`, `moof`, `traf`.

## Scope and limitations

- Decodes the box framing layer: 32-bit `size`, the 64-bit large-size form
  (`size == 1` with an 8-byte extended size), `size == 0` (box-to-end-of-file),
  and recursion into the known container boxes above. Unknown boxes are treated
  as leaves.
- Box payloads are not interpreted — no `ftyp` brands, sample tables, codec
  configuration, full-box version/flags, or `uuid` extended types.
- 64-bit sizes are read into the platform `int`; extremely large files may
  exceed a narrow `int` range.

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-mp4
smlpkg sync
```

Reference from your `.mlb`:

```
lib/github.com/sjqtentacles/sml-mp4/mp4.mlb
```

## Building and testing

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make clean
```

## Project layout

```
sml.pkg
Makefile
lib/github.com/sjqtentacles/sml-mp4/
  mp4.sig
  mp4.sml      recursive box-tree parser (containers + 64-bit largesize)
  mp4.mlb
test/
  test.sml     flat boxes, recursion, nesting, largesize, findAll
```

## License

MIT. See [LICENSE](LICENSE).
