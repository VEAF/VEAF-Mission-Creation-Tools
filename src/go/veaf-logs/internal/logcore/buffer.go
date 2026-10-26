package logcore

import (
	"io"
	"os"
)

// Buffer is an addressable sequence of bytes whose size may grow.
//
// The file implementation never keeps a handle open between two reads: under
// Windows an open handle prevents anyone from renaming the file, and renaming
// dcs.log to .old at launch is exactly what DCS does (see buffer.py).
type Buffer interface {
	Size() int64
	Slice(start int64, length int64) []byte
	// Refresh takes into account what was written since, and returns the size.
	Refresh() int64
}

// BytesBuffer is a content already in memory: an extracted archive, or a test.
type BytesBuffer struct{ Data []byte }

func (b *BytesBuffer) Size() int64    { return int64(len(b.Data)) }
func (b *BytesBuffer) Refresh() int64 { return b.Size() }
func (b *BytesBuffer) Slice(start, length int64) []byte {
	if start >= int64(len(b.Data)) || length <= 0 {
		return nil
	}
	end := start + length
	if end > int64(len(b.Data)) {
		end = int64(len(b.Data))
	}
	return b.Data[start:end]
}

// FileBuffer reads a file on demand and never keeps it open.
type FileBuffer struct {
	Path string
	size int64
}

// NewFileBuffer opens (stats) the file.
func NewFileBuffer(path string) *FileBuffer {
	b := &FileBuffer{Path: path}
	b.Refresh()
	return b
}

func (b *FileBuffer) Size() int64 { return b.size }

func (b *FileBuffer) Slice(start, length int64) []byte {
	if length <= 0 {
		return nil
	}
	f, err := os.Open(b.Path)
	if err != nil {
		// The file just disappeared: the caller notices at the next rotation check.
		return nil
	}
	defer f.Close()
	buf := make([]byte, length)
	n, err := f.ReadAt(buf, start)
	if err != nil && err != io.EOF {
		return nil
	}
	return buf[:n]
}

func (b *FileBuffer) Refresh() int64 {
	info, err := os.Stat(b.Path)
	if err != nil {
		b.size = 0
	} else {
		b.size = info.Size()
	}
	return b.size
}
