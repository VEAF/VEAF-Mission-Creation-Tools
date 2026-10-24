package sshlog

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"errors"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// testServer is a real SSH server on 127.0.0.1 with an SFTP subsystem serving
// the local file system, authenticating one public key.
type testServer struct {
	port    int
	hostKey ssh.PublicKey
	ln      net.Listener
}

func startServer(t *testing.T, authorized ssh.PublicKey) *testServer {
	t.Helper()
	_, hostPriv, _ := ed25519.GenerateKey(rand.Reader)
	hostSigner, err := ssh.NewSignerFromKey(hostPriv)
	if err != nil {
		t.Fatal(err)
	}
	cfg := &ssh.ServerConfig{PublicKeyCallback: func(_ ssh.ConnMetadata, key ssh.PublicKey) (*ssh.Permissions, error) {
		if bytes.Equal(key.Marshal(), authorized.Marshal()) {
			return nil, nil
		}
		return nil, errors.New("unknown key")
	}}
	cfg.AddHostKey(hostSigner)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go serve(c, cfg)
		}
	}()
	return &testServer{port: ln.Addr().(*net.TCPAddr).Port, hostKey: hostSigner.PublicKey(), ln: ln}
}

func serve(c net.Conn, cfg *ssh.ServerConfig) {
	_, chans, reqs, err := ssh.NewServerConn(c, cfg)
	if err != nil {
		c.Close()
		return
	}
	go ssh.DiscardRequests(reqs)
	for nc := range chans {
		if nc.ChannelType() != "session" {
			nc.Reject(ssh.UnknownChannelType, "no")
			continue
		}
		ch, creqs, _ := nc.Accept()
		go func() {
			for r := range creqs {
				ok := r.Type == "subsystem" && len(r.Payload) >= 4 && string(r.Payload[4:]) == "sftp"
				r.Reply(ok, nil)
				if ok {
					if s, err := sftp.NewServer(ch); err == nil {
						s.Serve()
					}
					ch.Close()
				}
			}
		}()
	}
}

// writeKey writes a new ed25519 key in OpenSSH format and returns its path and public key.
func writeKey(t *testing.T) (string, ssh.PublicKey) {
	t.Helper()
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	block, err := ssh.MarshalPrivateKey(priv, "")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "id_test")
	if err := os.WriteFile(path, pem.EncodeToMemory(block), 0o600); err != nil {
		t.Fatal(err)
	}
	sp, _ := ssh.NewPublicKey(pub)
	return path, sp
}

func serverFor(srv *testServer, keyPath string) Server {
	return Server{Name: "test", Host: "127.0.0.1", Port: srv.port, User: "veaf", Key: keyPath, Logs: map[string]string{}}
}

func opts(srv *testServer) Options {
	return Options{HostKey: ssh.FixedHostKey(srv.hostKey), Agent: "-", NoDefaultKeys: true}
}

func TestConnectAndReadARemoteFile(t *testing.T) {
	keyPath, pub := writeKey(t)
	srv := startServer(t, pub)
	file := filepath.Join(t.TempDir(), "dcs.log")
	os.WriteFile(file, []byte("hello journal\n"), 0o644)

	c, err := Connect(serverFor(srv, keyPath), opts(srv))
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	size, err := c.Size(logcore.SFTPPath(file))
	if err != nil || size != 14 {
		t.Fatalf("Size = %d, %v", size, err)
	}
	f, err := c.Open(logcore.SFTPPath(file))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	f.Seek(6, io.SeekStart)
	got, _ := io.ReadAll(f)
	if string(got) != "journal\n" {
		t.Fatalf("read %q", got)
	}
	if _, err := c.Size(logcore.SFTPPath(file) + ".nope"); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("a missing file must be os.ErrNotExist (the mirror relies on it), got %v", err)
	}
}

// The whole chain: a journal on a server, mirrored through SSH + SFTP, indexed,
// followed across an append and a rotation.
func TestRemoteSourceOverRealSSH(t *testing.T) {
	keyPath, pub := writeKey(t)
	srv := startServer(t, pub)
	file := filepath.Join(t.TempDir(), "dcs.log")
	l := func(msg string) string { return "2026-08-31 11:50:40.872 INFO    APP (Main): " + msg + "\n" }
	os.WriteFile(file, []byte(l("one")+l("two")), 0o644)

	rules, err := logcore.DefaultRules()
	if err != nil {
		t.Fatal(err)
	}
	src, err := logcore.NewRemoteSource(file, "veaf@127.0.0.1:"+file, Connector(serverFor(srv, keyPath), opts(srv)))
	if err != nil {
		t.Fatal(err)
	}
	defer src.Close()
	store := logcore.NewStore(rules, src.Buffer())

	if added, _, err := src.Poll(store, 0); err != nil || added != 2 {
		t.Fatalf("first poll: added=%d err=%v", added, err)
	}
	f, _ := os.OpenFile(file, os.O_APPEND|os.O_WRONLY, 0)
	f.WriteString(l("three"))
	f.Close()
	if added, rotated, err := src.Poll(store, 0); err != nil || rotated || added != 1 {
		t.Fatalf("append: added=%d rotated=%v err=%v", added, rotated, err)
	}
	// DCS restarts: the file is renamed and a shorter new one starts.
	os.Rename(file, file+".old")
	os.WriteFile(file, []byte(l("fresh")), 0o644)
	added, rotated, err := src.Poll(store, 0)
	if err != nil || !rotated || added != 1 || store.Entry(0).Message != "fresh" {
		t.Fatalf("rotation: added=%d rotated=%v err=%v", added, rotated, err)
	}
	// The instance is stopped: the file is gone, the server still answers.
	os.Remove(file)
	if _, _, err := src.Poll(store, 0); !errors.Is(err, logcore.ErrRemoteFileMissing) {
		t.Fatalf("missing file: err = %v", err)
	}
}

func TestConnectRefusals(t *testing.T) {
	keyPath, pub := writeKey(t)
	srv := startServer(t, pub)

	// A server key that is not the expected one.
	otherPub, _, _ := ed25519.GenerateKey(rand.Reader)
	wrong, _ := ssh.NewPublicKey(otherPub)
	o := opts(srv)
	o.HostKey = ssh.FixedHostKey(wrong)
	if _, err := Connect(serverFor(srv, keyPath), o); err == nil {
		t.Fatal("a host key that does not match must be refused")
	}

	// A client key the server does not know.
	otherKey, _ := writeKey(t)
	if _, err := Connect(serverFor(srv, otherKey), opts(srv)); err == nil {
		t.Fatal("an unknown client key must be refused")
	}

	// No key at all.
	if _, err := Connect(Server{Host: "127.0.0.1", Port: srv.port, User: "veaf"}, opts(srv)); err == nil || !strings.Contains(err.Error(), "no usable SSH key") {
		t.Fatalf("no key: err = %v", err)
	}

	// Nothing listens: fast failure, not a hang.
	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()
	start := time.Now()
	if _, err := Connect(Server{Host: "127.0.0.1", Port: port, User: "veaf", Key: keyPath}, opts(srv)); err == nil {
		t.Fatal("connection to a closed port must fail")
	}
	if time.Since(start) > 2*connectTimeout {
		t.Fatalf("failure took %v", time.Since(start))
	}
}

func TestAServerThatSaysNothingDoesNotFreezeTheConnection(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			defer c.Close() // accepts the TCP connection, never speaks SSH
		}
	}()
	keyPath, pub := writeKey(t)
	srv := startServer(t, pub)
	port := ln.Addr().(*net.TCPAddr).Port
	start := time.Now()
	_, err = Connect(Server{Host: "127.0.0.1", Port: port, User: "veaf", Key: keyPath}, opts(srv))
	if err == nil {
		t.Fatal("expected a failure")
	}
	if d := time.Since(start); d > connectTimeout+2*time.Second {
		t.Fatalf("the handshake was not bounded: %v", d)
	}
}

func TestPassphraseProtectedKeyIsExplained(t *testing.T) {
	_, priv, _ := ed25519.GenerateKey(rand.Reader)
	block, err := ssh.MarshalPrivateKeyWithPassphrase(priv, "", []byte("secret"))
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "id_locked")
	os.WriteFile(path, pem.EncodeToMemory(block), 0o600)
	_, err = readKey(path)
	if err == nil || !strings.Contains(err.Error(), "passphrase") {
		t.Fatalf("err = %v, want a message about the passphrase", err)
	}
}

const sampleConfig = `
lang: fr
servers:
  veaf:
    host: dcs.veaf.org
    user: veaf
    key: ~/.ssh/id_ed25519
    logs:
      private1: C:/Users/veaf/Saved Games/private1_server/Logs/dcs.log
      foothold1: C:/Users/veaf/Saved Games/foothold1_server/Logs/dcs.log
      bot: C:/Users/veaf/VEAF-DCSServerBot/logs/dcssb-dcs-veaf-org.log
  other:
    host: 10.0.0.2
    user: dcs
    port: 2222
    logs: {a: /var/log/a.log}
`

func TestParseServers(t *testing.T) {
	servers, err := ParseServers([]byte(sampleConfig))
	if err != nil {
		t.Fatal(err)
	}
	if len(servers) != 2 || servers[0].Name != "veaf" || servers[1].Name != "other" {
		t.Fatalf("servers = %+v (declaration order must be kept)", servers)
	}
	v := servers[0]
	if v.Host != "dcs.veaf.org" || v.User != "veaf" || v.Port != 22 || !strings.HasSuffix(filepath.ToSlash(v.Key), "/.ssh/id_ed25519") || strings.Contains(v.Key, "~") {
		t.Fatalf("veaf = %+v", v)
	}
	if got := strings.Join(v.Instances(), ","); got != "private1,foothold1,bot" {
		t.Fatalf("instances %q: declaration order lost", got)
	}
	if servers[1].Port != 2222 {
		t.Fatalf("port = %d", servers[1].Port)
	}
}

func TestParseServersRejections(t *testing.T) {
	cases := map[string]string{
		"no host":        "servers:\n  a:\n    user: u\n    logs: {x: /p}\n",
		"no user":        "servers:\n  a:\n    host: h\n    logs: {x: /p}\n",
		"bad port":       "servers:\n  a:\n    host: h\n    user: u\n    port: 70000\n    logs: {x: /p}\n",
		"bool port":      "servers:\n  a:\n    host: h\n    user: u\n    port: true\n    logs: {x: /p}\n",
		"no logs":        "servers:\n  a:\n    host: h\n    user: u\n",
		"empty logs":     "servers:\n  a:\n    host: h\n    user: u\n    logs: {}\n",
		"empty log path": "servers:\n  a:\n    host: h\n    user: u\n    logs: {x: ''}\n",
		"not a mapping":  "servers: [a, b]\n",
		"server scalar":  "servers:\n  a: oops\n",
		"empty key":      "servers:\n  a:\n    host: h\n    user: u\n    key: ''\n    logs: {x: /p}\n",
	}
	for name, doc := range cases {
		if _, err := ParseServers([]byte(doc)); err == nil {
			t.Errorf("%s: accepted, want an error", name)
		}
	}
	for name, doc := range map[string]string{"no block": "lang: fr\n", "null block": "servers:\n"} {
		if s, err := ParseServers([]byte(doc)); err != nil || len(s) != 0 {
			t.Errorf("%s: %v %v, want an empty list", name, s, err)
		}
	}
}

func TestLoadServersTakesTheFirstFileFound(t *testing.T) {
	dir := t.TempDir()
	missing := filepath.Join(dir, "none.yaml")
	first := filepath.Join(dir, "first.yaml")
	os.WriteFile(first, []byte(sampleConfig), 0o644)
	servers, err := LoadServers(missing, first)
	if err != nil || len(servers) != 2 {
		t.Fatalf("%v %v", servers, err)
	}
	if s, err := LoadServers(missing); err != nil || s != nil {
		t.Fatalf("no file: %v %v", s, err)
	}
}
