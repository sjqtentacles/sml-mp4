# sml-mp4

[![CI](https://github.com/sjqtentacles/sml-mp4/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-mp4/actions/workflows/ci.yml)

ISO Base Media File Format (MP4 / `.mov`) parser for Standard ML. Builds the
recursive **box tree** (with byte offsets), and decodes the common metadata
boxes: `ftyp` brands, FullBox version/flags, and the `mvhd`/`tkhd`/`mdhd`
timescale + duration — including overall movie duration in seconds.

## API

```sml
datatype box = Box of
  { kind : string, size : int, offset : int, dataOffset : int, children : box list }

(* accessors *)
val kind/size/offset/dataOffset/children : box -> ...
val payloadLength : box -> int

(* tree *)
val parse       : Word8Vector.vector -> box list
val isContainer : string -> bool
val findAll     : string -> box list -> box list
val find        : string -> box list -> box option
val path        : string list -> box list -> box option   (* e.g. ["moov","trak","mdia"] *)
val payload     : Word8Vector.vector -> box -> Word8Vector.vector

(* typed boxes *)
val ftyp    : Word8Vector.vector -> box -> { major:string, minor:int, compatible:string list } option
val fullBox : Word8Vector.vector -> box -> { version:int, flags:int }
val mvhd    : Word8Vector.vector -> box -> { timescale:int, duration:int } option
val tkhd    : Word8Vector.vector -> box -> { trackId:int, duration:int } option
val mdhd    : Word8Vector.vector -> box -> { timescale:int, duration:int } option
val movieDuration : Word8Vector.vector -> box list -> real option   (* seconds *)
val toString : box list -> string
```

## Examples

```sml
val boxes = Mp4.parse data

(* navigate by path *)
val mdia = Mp4.path ["moov","trak","mdia"] boxes

(* read brands *)
val SOME ft = Mp4.ftyp data (valOf (Mp4.find "ftyp" boxes))
(* { major = "isom", minor = 512, compatible = ["isom","avc1"] } *)

(* overall duration in seconds *)
val secs = Mp4.movieDuration data boxes      (* SOME 5.0 *)

(* raw payload bytes of a leaf box *)
val raw = Mp4.payload data (valOf (Mp4.find "mdat" boxes))

print (Mp4.toString boxes)                   (* indented box-tree dump *)
```

Recognized container boxes (descended into): `moov`, `trak`, `mdia`, `minf`,
`stbl`, `udta`, `dinf`, `edts`, `mvex`, `moof`, `traf`.

## Scope and limitations

> **Breaking change:** `Box` now carries `offset` and `dataOffset` fields (so
> payloads and typed boxes can be sliced from the original vector). Pattern
> matches that named only `{kind, size, children}` must add the new fields or
> use the accessor functions.

- Decodes the box framing layer (32-bit `size`, the 64-bit large-size form,
  `size == 0` box-to-EOF) plus the metadata boxes listed above. Other payloads
  (sample tables, codec config, `uuid` types) are left as raw bytes.
- `mvhd`/`tkhd`/`mdhd` handle FullBox version 0 and version 1 layouts.
- 64-bit sizes/durations are read into the platform `int`; extremely large
  files may exceed a narrow `int` range.

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
hand-builds a minimal in-memory `ftyp` + `moov`/`mvhd` box buffer, `parse`s
it, walks the box tree with `find`/`path`, and reads `ftyp` brands, `mvhd`
timescale/duration, and `movieDuration` (output is byte-identical under
MLton and Poly/ML):

```
ISO BMFF box tree:
ftyp (size=28, off=0)
moov (size=36, off=28)
  mvhd (size=28, off=36)

ftyp fields:
  payloadLength = 20
  major=isom minor=512 compatible=[isom,iso2,mp41]

moov/mvhd fields:
  timescale=1000 duration=5000

movieDuration (seconds):
  5.000
```

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
  mp4.sml      box-tree parser + ftyp/FullBox/mvhd/tkhd/mdhd + find/path/payload
  mp4.mlb
test/
  test.sml     framing, nesting, largesize, find/path, brands, timescale/duration, payload
```

## License

MIT. See [LICENSE](LICENSE).
