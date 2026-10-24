package logcore

import (
	"bytes"
	"sort"
)

// Snapshot returns a read-only view of the entries indexed so far, usable by
// Search while the live store keeps growing. The offsets never change once
// appended, but the length of the last entry grows in place when a continuation
// line arrives: it is copied, or the search would read it while the indexer writes it.
func (s *Store) Snapshot() *Store {
	n := len(s.offset)
	length := make([]uint32, n)
	copy(length, s.length)
	return &Store{buffer: s.buffer, offset: s.offset[:n:n], length: length}
}

const searchChunk = 8 << 20

// Search returns the indexes of the entries whose full text (header line and
// continuation lines) contains `needle`, ignoring ASCII case. It reads the
// journal in blocks, never whole, and a match cannot straddle two entries
// since an entry never ends in the middle of a line. `cancel` is polled
// between blocks.
func (s *Store) Search(needle string, cancel func() bool) []int32 {
	return s.SearchFrom(needle, 0, cancel)
}

// SearchFrom is Search restricted to the entries from index `from` on, to
// extend a result when the journal grows.
func (s *Store) SearchFrom(needle string, from int, cancel func() bool) []int32 {
	if needle == "" {
		return nil
	}
	want := asciiLower([]byte(needle))
	var hits []int32
	total := len(s.offset)
	start := from
	for start < total {
		if cancel != nil && cancel() {
			return hits
		}
		base := s.offset[start]
		stop := start
		for stop < total && s.offset[stop]+int64(s.length[stop])-base <= searchChunk {
			stop++
		}
		if stop == start {
			stop = start + 1 // an entry bigger than the block is handled alone
		}
		end := s.offset[stop-1] + int64(s.length[stop-1])
		block := asciiLower(s.buffer.Slice(base, end-base))
		last := -1
		for pos := 0; ; {
			i := bytes.Index(block[pos:], want)
			if i < 0 {
				break
			}
			abs := base + int64(pos+i)
			entry := start + sort.Search(stop-start, func(k int) bool { return s.offset[start+k] > abs }) - 1
			if entry != last {
				hits = append(hits, int32(entry))
				last = entry
			}
			// Resume at the next entry: one hit per entry is all that is needed.
			if entry+1 >= stop {
				break
			}
			pos = int(s.offset[entry+1] - base)
		}
		start = stop
	}
	return hits
}

// iterBlocks walks the journal in blocks of at most searchChunk bytes, cut on
// entry boundaries exactly as Python's `LogStore.iter_blocks`: the filters run
// a pattern over each block, and a pattern that sees the edges of a block (`\A`,
// `\z`, a match across a newline) finds the same entries on both sides only if
// both cut the journal in the same places.
func (s *Store) iterBlocks(fn func(first int, base int64, data []byte)) {
	total := len(s.offset)
	for start := 0; start < total; {
		base := s.offset[start]
		stop := start
		for stop < total && s.offset[stop]+int64(s.length[stop])-base <= searchChunk {
			stop++
		}
		if stop == start {
			stop = start + 1 // an entry bigger than the block is handled alone
		}
		end := s.offset[stop-1] + int64(s.length[stop-1])
		fn(start, base, s.buffer.Slice(base, end-base))
		start = stop
	}
}

// asciiLower lowers ASCII letters in place of a copy, byte for byte: Unicode
// lowering can change the length of the text and so shift every offset.
func asciiLower(b []byte) []byte {
	out := make([]byte, len(b))
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			c += 'a' - 'A'
		}
		out[i] = c
	}
	return out
}
