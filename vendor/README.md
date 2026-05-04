# vendored deps

Source trees here are gitignored (huge); only this README and any
`*.patch` files are tracked.

## librime 1.16.0

```bash
git clone --recurse-submodules https://github.com/rime/librime.git vendor/librime
cd vendor/librime
git checkout 1.16.0
git submodule update --init --recursive
```

Apply our patch before building:

```bash
cd vendor/librime
git apply ../librime-1.16.0-peek-sort.patch
make release
```

The patch fixes a `DictEntryIterator::Peek()` bug where the first
candidate is returned without sorting chunks. When an algebra-derived
spelling shares an input with a direct spelling and sorts alphabetically
earlier in the syllabary (e.g. `yaai < yai`), the algebra-derived chunk
wins position #1 regardless of weight. The patch calls `Sort()` once
before the first Peek. See `docs/RESUME.md` for full reproduction.

Brew deps for librime build: `cmake boost leveldb marisa yaml-cpp opencc googletest pkg-config ninja glog`.
