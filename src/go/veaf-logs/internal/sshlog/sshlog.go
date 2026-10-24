// Package sshlog opens the journals of DCS servers over SSH + SFTP. It is the
// network half of the remote source (the mirror itself is in logcore) and a port
// of the connection and configuration parts of the Python `remote.py` and
// `user_config.py`.
//
// No password goes through here: authentication is by key only (the key of the
// configuration, else the SSH agent, else the default keys of ~/.ssh).
package sshlog

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/agent"
	"golang.org/x/crypto/ssh/knownhosts"
	"gopkg.in/yaml.v3"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// connectTimeout bounds each step of the connection (TCP, SSH banner and key
// exchange, authentication, SFTP channel): a server that accepts the connection
// and then says nothing must not hold a tab forever. A variable for the tests.
var connectTimeout = 5 * time.Second

// Server is a DCS server reachable over SSH with the logs it hosts: `Logs` maps
// an instance name (`private1`) to the remote path of its dcs.log.
type Server struct {
	Name string
	Host string
	User string
	Port int
	Key  string
	Logs map[string]string
	// logOrder keeps the declaration order of the instances.
	logOrder []string
}

// Instances returns the instance names in declaration order.
func (s Server) Instances() []string { return s.logOrder }

// ConfigPaths are the places the configuration is looked for, like
// `user_config.py`: ~/veafmct.yaml, then $VEAF_HOME or ~/.veaf/config.yaml.
func ConfigPaths() []string {
	home, _ := os.UserHomeDir()
	veafHome := os.Getenv("VEAF_HOME")
	if strings.TrimSpace(veafHome) == "" {
		veafHome = filepath.Join(home, ".veaf")
	}
	return []string{filepath.Join(home, "veafmct.yaml"), filepath.Join(veafHome, "config.yaml")}
}

// DefaultConfigPath is where a new configuration goes (`default_config_path`).
func DefaultConfigPath() string { return ConfigPaths()[0] }

// FindConfig is the configuration file in use, "" when there is none (`config_file_path`).
func FindConfig(paths ...string) string {
	if len(paths) == 0 {
		paths = ConfigPaths()
	}
	for _, p := range paths {
		if info, err := os.Stat(p); err == nil && !info.IsDir() {
			return p
		}
	}
	return ""
}

// LoadServers reads the `servers` block of the first configuration file found.
// None found, or no block: an empty list.
func LoadServers(paths ...string) ([]Server, error) {
	path := FindConfig(paths...)
	if path == "" {
		return nil, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseServers(data)
}

// ParseServers reads the `servers` block of a configuration, with the checks of
// the Python `_parse_server`.
func ParseServers(data []byte) ([]Server, error) {
	var doc struct {
		Servers yaml.Node `yaml:"servers"`
	}
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("configuration: %w", err)
	}
	node := doc.Servers
	if node.Kind == 0 || (node.Kind == yaml.ScalarNode && node.Tag == "!!null") {
		return nil, nil
	}
	if node.Kind != yaml.MappingNode {
		return nil, errors.New("servers: expected a mapping of server name to settings")
	}
	var out []Server
	for i := 0; i+1 < len(node.Content); i += 2 {
		name := node.Content[i].Value
		s, err := parseServer(name, node.Content[i+1])
		if err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, nil
}

func parseServer(name string, n *yaml.Node) (Server, error) {
	if n.Kind != yaml.MappingNode {
		return Server{}, fmt.Errorf("servers.%s: expected a mapping (host, user, logs…)", name)
	}
	s := Server{Name: name, Port: 22, Logs: map[string]string{}}
	for i := 0; i+1 < len(n.Content); i += 2 {
		key, val := n.Content[i].Value, n.Content[i+1]
		switch key {
		case "host":
			s.Host = strings.TrimSpace(val.Value)
		case "user":
			s.User = strings.TrimSpace(val.Value)
		case "port":
			p, err := strconv.Atoi(val.Value)
			if err != nil || p < 1 || p > 65535 || val.Tag == "!!bool" {
				return Server{}, fmt.Errorf("servers.%s.port: expected an integer between 1 and 65535", name)
			}
			s.Port = p
		case "key":
			if strings.TrimSpace(val.Value) == "" {
				return Server{}, fmt.Errorf("servers.%s.key: expected a path", name)
			}
			s.Key = expandHome(strings.TrimSpace(val.Value))
		case "logs":
			if val.Kind != yaml.MappingNode || len(val.Content) == 0 {
				return Server{}, fmt.Errorf("servers.%s.logs: expected a non-empty mapping of instance name to log path", name)
			}
			for j := 0; j+1 < len(val.Content); j += 2 {
				inst, path := val.Content[j].Value, strings.TrimSpace(val.Content[j+1].Value)
				if path == "" {
					return Server{}, fmt.Errorf("servers.%s.logs.%s: expected a remote path", name, inst)
				}
				s.Logs[inst] = path
				s.logOrder = append(s.logOrder, inst)
			}
		}
	}
	if s.Host == "" || s.User == "" {
		return Server{}, fmt.Errorf("servers.%s: host and user are required, non-empty strings", name)
	}
	if len(s.Logs) == 0 {
		return Server{}, fmt.Errorf("servers.%s.logs: expected a non-empty mapping of instance name to log path", name)
	}
	return s, nil
}

func expandHome(p string) string {
	if p == "~" || strings.HasPrefix(p, "~/") || strings.HasPrefix(p, `~\`) {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, p[1:])
		}
	}
	return p
}

// AskHostKey asks whether to trust a server whose key is not in known_hosts:
// the host as known_hosts writes it, and the key's fingerprint.
type AskHostKey func(host, fingerprint string) bool

// Options of Connect. The zero value is the normal behaviour.
type Options struct {
	// HostKey verifies the server. nil: known_hosts, see KnownHosts and Ask.
	HostKey ssh.HostKeyCallback
	// KnownHosts is the known_hosts file; "" is ~/.ssh/known_hosts.
	KnownHosts string
	// Ask is called for a server absent from known_hosts; yes appends its key
	// there. nil refuses: accepting silently would not check the server at all.
	Ask AskHostKey
	// Agent is the address of an SSH agent socket; "" uses SSH_AUTH_SOCK.
	Agent string
	// NoDefaultKeys skips ~/.ssh/id_* (tests).
	NoDefaultKeys bool
}

// Client is an open SSH session and its SFTP channel; it is a logcore.SFTPClient.
type Client struct {
	ssh  *ssh.Client
	sftp *sftp.Client
}

// Size returns the size of a remote file.
func (c *Client) Size(path string) (int64, error) {
	info, err := c.sftp.Stat(path)
	if err != nil {
		return 0, err
	}
	return info.Size(), nil
}

// Open opens a remote file for reading.
func (c *Client) Open(path string) (logcore.RemoteFile, error) { return c.sftp.Open(path) }

// Close ends the SFTP channel and the SSH session.
func (c *Client) Close() error {
	err := c.sftp.Close()
	if e := c.ssh.Close(); err == nil {
		err = e
	}
	return err
}

// Connect opens the SSH session of a server and its SFTP channel.
func Connect(s Server, o Options) (*Client, error) {
	signers, err := loadSigners(s, o)
	if err != nil {
		return nil, err
	}
	addr := net.JoinHostPort(s.Host, strconv.Itoa(s.Port))
	conn, err := net.DialTimeout("tcp", addr, connectTimeout)
	if err != nil {
		return nil, err
	}
	hostKey := o.HostKey
	if hostKey == nil {
		// The question waits for a person: the deadline stops while it is asked.
		ask := o.Ask
		if ask != nil {
			ask = func(host, fingerprint string) bool {
				conn.SetDeadline(time.Time{})
				ok := o.Ask(host, fingerprint)
				conn.SetDeadline(time.Now().Add(connectTimeout)) // counted from the answer
				return ok
			}
		}
		if hostKey, err = knownHostsCallback(o.KnownHosts, ask); err != nil {
			conn.Close()
			return nil, err
		}
	}
	cfg := &ssh.ClientConfig{
		User:            s.User,
		Auth:            []ssh.AuthMethod{ssh.PublicKeysCallback(func() ([]ssh.Signer, error) { return signers, nil })},
		HostKeyCallback: hostKey,
		Timeout:         connectTimeout,
	}
	// The deadline bounds the SSH handshake, the authentication and the SFTP channel.
	conn.SetDeadline(time.Now().Add(connectTimeout))
	sconn, chans, reqs, err := ssh.NewClientConn(conn, addr, cfg)
	if err != nil {
		conn.Close()
		return nil, err
	}
	client := ssh.NewClient(sconn, chans, reqs)
	sc, err := sftp.NewClient(client)
	if err != nil {
		// The SFTP subsystem refused: do not leave the SSH session open.
		client.Close()
		return nil, err
	}
	conn.SetDeadline(time.Time{})
	return &Client{ssh: client, sftp: sc}, nil
}

// Connector adapts Connect to what logcore.RemoteSource wants.
func Connector(s Server, o Options) logcore.Connector {
	return func() (logcore.SFTPClient, io.Closer, error) {
		c, err := Connect(s, o)
		if err != nil {
			return nil, nil, err
		}
		return c, c, nil
	}
}

// knownHostsCallback checks the server against known_hosts. A server absent
// from it is asked about (`accept_host_key`); a known server whose key changed is
// refused without asking, as OpenSSH does. No file yet is a file with no server.
func knownHostsCallback(path string, ask AskHostKey) (ssh.HostKeyCallback, error) {
	if path == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, err
		}
		path = filepath.Join(home, ".ssh", "known_hosts")
	}
	var cb ssh.HostKeyCallback
	if _, err := os.Stat(path); err == nil {
		if cb, err = knownhosts.New(path); err != nil {
			return nil, fmt.Errorf("%s: %w", path, err)
		}
	}
	return func(hostname string, remote net.Addr, key ssh.PublicKey) error {
		if cb != nil {
			err := cb(hostname, remote, key)
			var ke *knownhosts.KeyError
			if !errors.As(err, &ke) || sameType(ke.Want, key) {
				return err // known (nil), or known with another key of this type
			}
		}
		host, fingerprint := knownhosts.Normalize(hostname), Fingerprint(key)
		if ask == nil || !ask(host, fingerprint) {
			return fmt.Errorf("host key of %s refused (%s)", host, fingerprint)
		}
		return rememberHostKey(path, host, key)
	}, nil
}

// sameType tells that known_hosts holds a key of the presented key's type: only
// then is a different key a changed one. Known under other types only, the
// server is asked about, as paramiko does.
func sameType(known []knownhosts.KnownKey, key ssh.PublicKey) bool {
	for _, k := range known {
		if k.Key.Type() == key.Type() {
			return true
		}
	}
	return false
}

// rememberHostKey appends one line to known_hosts, leaving the rest of it alone.
func rememberHostKey(path, host string, key ssh.PublicKey) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	line := knownhosts.Line([]string{host}, key) + "\n"
	if data, err := os.ReadFile(path); err == nil && len(data) > 0 && data[len(data)-1] != '\n' {
		line = "\n" + line // a last line with no newline would swallow ours
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	_, err = f.WriteString(line)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

// Fingerprint is the SHA256 fingerprint of a key, as OpenSSH prints it.
func Fingerprint(key ssh.PublicKey) string {
	sum := sha256.Sum256(key.Marshal())
	return key.Type() + " SHA256:" + strings.TrimRight(base64.StdEncoding.EncodeToString(sum[:]), "=")
}

// loadSigners gathers the keys to offer: the configured one, the agent's, the default ones.
func loadSigners(s Server, o Options) ([]ssh.Signer, error) {
	var signers []ssh.Signer
	if s.Key != "" {
		sg, err := readKey(s.Key)
		if err != nil {
			return nil, err
		}
		signers = append(signers, sg)
	}
	sock := o.Agent
	if sock == "" {
		sock = os.Getenv("SSH_AUTH_SOCK")
	}
	if sock != "" {
		if conn, err := net.Dial("unix", sock); err == nil {
			if ags, err := agent.NewClient(conn).Signers(); err == nil {
				signers = append(signers, ags...)
			}
		}
	}
	if !o.NoDefaultKeys {
		home, _ := os.UserHomeDir()
		for _, name := range []string{"id_ed25519", "id_ecdsa", "id_rsa"} {
			path := filepath.Join(home, ".ssh", name)
			if path == s.Key {
				continue
			}
			if sg, err := readKey(path); err == nil {
				signers = append(signers, sg)
			}
		}
	}
	if len(signers) == 0 {
		return nil, errors.New("no usable SSH key (set `key:` for the server, or load one into an SSH agent)")
	}
	return signers, nil
}

func readKey(path string) (ssh.Signer, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	sg, err := ssh.ParsePrivateKey(data)
	if err != nil {
		var missing *ssh.PassphraseMissingError
		if errors.As(err, &missing) {
			return nil, fmt.Errorf("%s is protected by a passphrase: load it into an SSH agent", path)
		}
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	// RSA keys sign with SHA-2 only: ssh-rsa (SHA-1) is refused, as the Python side does.
	if sg.PublicKey().Type() == ssh.KeyAlgoRSA {
		if as, ok := sg.(ssh.AlgorithmSigner); ok {
			if w, err := ssh.NewSignerWithAlgorithms(as, []string{ssh.KeyAlgoRSASHA256, ssh.KeyAlgoRSASHA512}); err == nil {
				return w, nil
			}
		}
	}
	return sg, nil
}
