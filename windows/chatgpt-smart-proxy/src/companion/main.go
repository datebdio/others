package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	apiAddr   = "127.0.0.1:17890"
	socksAddr = "127.0.0.1:10808"
	version   = "0.2.0"
)

type Node struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Type   string `json:"type"`
	Source string `json:"source"`
}

type State struct {
	Enabled    bool   `json:"enabled"`
	SelectedID string `json:"selectedId"`
	Nodes      []Node `json:"nodes"`
}

type App struct {
	mu       sync.Mutex
	baseDir  string
	dataDir  string
	xrayPath string
	cmd      *exec.Cmd
	logFile  *os.File
	server   *http.Server
	state    State
}

type statusResponse struct {
	Version      string `json:"version"`
	Running      bool   `json:"running"`
	Enabled      bool   `json:"enabled"`
	NodeCount    int    `json:"nodeCount"`
	SelectedID   string `json:"selectedId,omitempty"`
	SelectedName string `json:"selectedName,omitempty"`
	API          string `json:"api"`
	Socks        string `json:"socks"`
	XrayFound    bool   `json:"xrayFound"`
	LastLog      string `json:"lastLog,omitempty"`
}

type nodeView struct {
	Node
	Selected bool `json:"selected"`
}

func main() {
	exe, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}
	base := filepath.Dir(exe)
	data := filepath.Join(base, "data")
	if err := os.MkdirAll(data, 0700); err != nil {
		log.Fatal(err)
	}
	appLog, err := os.OpenFile(filepath.Join(data, "app.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err == nil {
		log.SetOutput(appLog)
		defer appLog.Close()
	}

	a := &App{
		baseDir:  base,
		dataDir:  data,
		xrayPath: filepath.Join(base, "core", xrayBinary()),
	}
	if err := a.loadState(); err != nil {
		log.Printf("load state: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/status", a.withCORS(a.handleStatus))
	mux.HandleFunc("/nodes", a.withCORS(a.handleNodes))
	mux.HandleFunc("/nodes/save", a.withCORS(a.handleNodeSave))
	mux.HandleFunc("/nodes/select", a.withCORS(a.handleNodeSelect))
	mux.HandleFunc("/nodes/delete", a.withCORS(a.handleNodeDelete))
	mux.HandleFunc("/nodes/ping", a.withCORS(a.handleNodePing))
	mux.HandleFunc("/proxy", a.withCORS(a.handleProxy))
	mux.HandleFunc("/quit", a.withCORS(a.handleQuit))

	a.server = &http.Server{Addr: apiAddr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}

	if a.state.Enabled && a.state.SelectedID != "" {
		if err := a.startXray(); err != nil {
			log.Printf("auto start xray: %v", err)
		}
	}

	log.Printf("ChatGPT Smart Proxy %s listening on http://%s", version, apiAddr)
	if err := a.server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func xrayBinary() string {
	if runtime.GOOS == "windows" {
		return "xray.exe"
	}
	return "xray"
}

func (a *App) statePath() string   { return filepath.Join(a.dataDir, "state.json") }
func (a *App) activePath() string  { return filepath.Join(a.dataDir, "active.json") }
func (a *App) xrayLogPath() string { return filepath.Join(a.dataDir, "xray.log") }

func (a *App) loadState() error {
	raw, err := os.ReadFile(a.statePath())
	if errors.Is(err, os.ErrNotExist) {
		a.state = State{}
		return nil
	}
	if err != nil {
		return err
	}
	var s State
	if err := json.Unmarshal(raw, &s); err != nil {
		return err
	}
	a.state = s
	return nil
}

func (a *App) saveStateLocked() error {
	raw, err := json.MarshalIndent(a.state, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(a.statePath(), raw, 0600)
}

func (a *App) selectedNodeLocked() *Node {
	for i := range a.state.Nodes {
		if a.state.Nodes[i].ID == a.state.SelectedID {
			return &a.state.Nodes[i]
		}
	}
	return nil
}

func (a *App) withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && !strings.HasPrefix(origin, "chrome-extension://") && !strings.HasPrefix(origin, "edge-extension://") {
			http.Error(w, "forbidden origin", http.StatusForbidden)
			return
		}
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func jsonOut(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func errOut(w http.ResponseWriter, err error) {
	jsonOut(w, http.StatusBadRequest, map[string]any{"ok": false, "error": err.Error()})
}

func decodeJSON(r *http.Request, dst any, max int64) error {
	return json.NewDecoder(io.LimitReader(r.Body, max)).Decode(dst)
}

func requireMethod(w http.ResponseWriter, r *http.Request, method string) bool {
	if r.Method != method {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return false
	}
	return true
}

func (a *App) handleStatus(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	selected := a.selectedNodeLocked()
	name, id := "", ""
	if selected != nil {
		name, id = selected.Name, selected.ID
	}
	_, xrErr := os.Stat(a.xrayPath)
	jsonOut(w, 200, statusResponse{
		Version: version, Running: a.runningLocked(), Enabled: a.state.Enabled,
		NodeCount: len(a.state.Nodes), SelectedID: id, SelectedName: name,
		API: apiAddr, Socks: socksAddr, XrayFound: xrErr == nil,
		LastLog: tailFile(a.xrayLogPath(), 1800),
	})
}

func (a *App) handleNodes(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	out := make([]nodeView, 0, len(a.state.Nodes))
	for _, n := range a.state.Nodes {
		out = append(out, nodeView{Node: n, Selected: n.ID == a.state.SelectedID})
	}
	jsonOut(w, 200, map[string]any{"nodes": out})
}

func (a *App) handleNodeSave(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		Source string `json:"source"`
	}
	if err := decodeJSON(r, &req, 4<<20); err != nil {
		errOut(w, err)
		return
	}
	req.Source = strings.TrimSpace(req.Source)
	if req.Source == "" {
		errOut(w, errors.New("节点链接或 Xray JSON 为空"))
		return
	}
	meta, _, err := inspectSource(req.Source)
	if err != nil {
		errOut(w, err)
		return
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		name = meta.Name
	}

	a.mu.Lock()
	var saved Node
	restart := false
	if req.ID == "" {
		saved = Node{ID: newID(), Name: name, Type: meta.Type, Source: req.Source}
		a.state.Nodes = append(a.state.Nodes, saved)
		if a.state.SelectedID == "" {
			a.state.SelectedID = saved.ID
		}
	} else {
		found := false
		for i := range a.state.Nodes {
			if a.state.Nodes[i].ID == req.ID {
				a.state.Nodes[i].Name = name
				a.state.Nodes[i].Type = meta.Type
				a.state.Nodes[i].Source = req.Source
				saved = a.state.Nodes[i]
				restart = a.state.Enabled && a.state.SelectedID == req.ID
				found = true
				break
			}
		}
		if !found {
			a.mu.Unlock()
			errOut(w, errors.New("找不到要编辑的节点"))
			return
		}
	}
	if err := a.saveStateLocked(); err != nil {
		a.mu.Unlock()
		errOut(w, err)
		return
	}
	a.mu.Unlock()

	if restart {
		if err := a.restartXray(); err != nil {
			errOut(w, err)
			return
		}
	}
	jsonOut(w, 200, map[string]any{"ok": true, "node": saved})
}

func (a *App) handleNodeSelect(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		ID string `json:"id"`
	}
	if err := decodeJSON(r, &req, 1<<20); err != nil {
		errOut(w, err)
		return
	}

	a.mu.Lock()
	found := false
	for _, n := range a.state.Nodes {
		if n.ID == req.ID {
			found = true
			break
		}
	}
	if !found {
		a.mu.Unlock()
		errOut(w, errors.New("节点不存在"))
		return
	}
	changed := a.state.SelectedID != req.ID
	a.state.SelectedID = req.ID
	enabled := a.state.Enabled
	if err := a.saveStateLocked(); err != nil {
		a.mu.Unlock()
		errOut(w, err)
		return
	}
	a.mu.Unlock()

	if changed && enabled {
		if err := a.restartXray(); err != nil {
			errOut(w, err)
			return
		}
	}
	jsonOut(w, 200, map[string]any{"ok": true})
}

func (a *App) handleNodeDelete(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		ID string `json:"id"`
	}
	if err := decodeJSON(r, &req, 1<<20); err != nil {
		errOut(w, err)
		return
	}

	a.mu.Lock()
	idx := -1
	wasSelected := false
	for i, n := range a.state.Nodes {
		if n.ID == req.ID {
			idx = i
			wasSelected = n.ID == a.state.SelectedID
			break
		}
	}
	if idx < 0 {
		a.mu.Unlock()
		errOut(w, errors.New("节点不存在"))
		return
	}
	a.state.Nodes = append(a.state.Nodes[:idx], a.state.Nodes[idx+1:]...)
	if wasSelected {
		if len(a.state.Nodes) > 0 {
			a.state.SelectedID = a.state.Nodes[0].ID
		} else {
			a.state.SelectedID = ""
			a.state.Enabled = false
		}
	}
	enabled := a.state.Enabled
	if err := a.saveStateLocked(); err != nil {
		a.mu.Unlock()
		errOut(w, err)
		return
	}
	a.mu.Unlock()

	if wasSelected {
		if enabled {
			if err := a.restartXray(); err != nil {
				errOut(w, err)
				return
			}
		} else {
			_ = a.stopXray()
			_ = os.Remove(a.activePath())
		}
	}
	jsonOut(w, 200, map[string]any{"ok": true, "enabled": enabled})
}

func (a *App) handleNodePing(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		ID string `json:"id"`
	}
	if err := decodeJSON(r, &req, 1<<20); err != nil {
		errOut(w, err)
		return
	}

	a.mu.Lock()
	var n *Node
	for i := range a.state.Nodes {
		if a.state.Nodes[i].ID == req.ID {
			x := a.state.Nodes[i]
			n = &x
			break
		}
	}
	a.mu.Unlock()
	if n == nil {
		errOut(w, errors.New("节点不存在"))
		return
	}

	_, ep, err := inspectSource(n.Source)
	if err != nil {
		errOut(w, err)
		return
	}
	if ep.Host == "" || ep.Port == 0 {
		errOut(w, errors.New("无法从该节点配置提取服务器地址和端口"))
		return
	}
	start := time.Now()
	d := net.Dialer{Timeout: 4 * time.Second}
	c, err := d.Dial("tcp", net.JoinHostPort(ep.Host, strconv.Itoa(ep.Port)))
	if err != nil {
		errOut(w, fmt.Errorf("TCP 连接失败: %w", err))
		return
	}
	_ = c.Close()
	ms := time.Since(start).Milliseconds()
	if ms < 1 {
		ms = 1
	}
	jsonOut(w, 200, map[string]any{"ok": true, "latencyMs": ms})
}

func (a *App) handleProxy(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		Enabled bool `json:"enabled"`
	}
	if err := decodeJSON(r, &req, 1<<20); err != nil {
		errOut(w, err)
		return
	}

	if req.Enabled {
		a.mu.Lock()
		if a.selectedNodeLocked() == nil {
			a.mu.Unlock()
			errOut(w, errors.New("请先添加并选择一个节点"))
			return
		}
		a.state.Enabled = true
		if err := a.saveStateLocked(); err != nil {
			a.mu.Unlock()
			errOut(w, err)
			return
		}
		a.mu.Unlock()
		if err := a.startXray(); err != nil {
			a.mu.Lock()
			a.state.Enabled = false
			_ = a.saveStateLocked()
			a.mu.Unlock()
			errOut(w, err)
			return
		}
	} else {
		a.mu.Lock()
		a.state.Enabled = false
		err := a.saveStateLocked()
		a.mu.Unlock()
		if err != nil {
			errOut(w, err)
			return
		}
		_ = a.stopXray()
		_ = os.Remove(a.activePath())
	}
	jsonOut(w, 200, map[string]any{"ok": true, "enabled": req.Enabled})
}

func (a *App) handleQuit(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	_ = a.stopXray()
	jsonOut(w, 200, map[string]any{"ok": true})
	go func() {
		time.Sleep(100 * time.Millisecond)
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = a.server.Shutdown(ctx)
	}()
}

func (a *App) runningLocked() bool {
	return a.cmd != nil && a.cmd.Process != nil && a.cmd.ProcessState == nil
}

func (a *App) writeActiveConfigLocked() error {
	n := a.selectedNodeLocked()
	if n == nil {
		return errors.New("未选择节点")
	}
	_, _, err := inspectSource(n.Source)
	if err != nil {
		return err
	}
	cfg, err := configFromSource(n.Source)
	if err != nil {
		return err
	}
	raw, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(a.activePath(), raw, 0600)
}

func (a *App) startXray() error { a.mu.Lock(); defer a.mu.Unlock(); return a.startXrayLocked() }
func (a *App) startXrayLocked() error {
	if a.runningLocked() {
		return nil
	}
	if _, err := os.Stat(a.xrayPath); err != nil {
		return fmt.Errorf("找不到 Xray: %s", a.xrayPath)
	}
	if err := a.writeActiveConfigLocked(); err != nil {
		return err
	}
	lf, err := os.OpenFile(a.xrayLogPath(), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		return err
	}
	cmd := exec.Command(a.xrayPath, "run", "-config", a.activePath())
	cmd.Dir = a.baseDir
	cmd.Stdout = lf
	cmd.Stderr = lf
	hideChildWindow(cmd)
	if err := cmd.Start(); err != nil {
		_ = lf.Close()
		return err
	}
	a.cmd, a.logFile = cmd, lf
	go func(c *exec.Cmd, f *os.File) {
		err := c.Wait()
		_ = f.Close()
		a.mu.Lock()
		if a.cmd == c {
			a.cmd = nil
			a.logFile = nil
		}
		a.mu.Unlock()
		if err != nil {
			log.Printf("xray exited: %v", err)
		}
	}(cmd, lf)
	time.Sleep(350 * time.Millisecond)
	if cmd.ProcessState != nil {
		return errors.New("Xray 启动后立即退出，请查看 data\\xray.log")
	}
	return nil
}

func (a *App) stopXray() error { a.mu.Lock(); defer a.mu.Unlock(); return a.stopXrayLocked() }
func (a *App) stopXrayLocked() error {
	if !a.runningLocked() {
		a.cmd = nil
		return nil
	}
	p := a.cmd.Process
	if runtime.GOOS == "windows" {
		_ = p.Kill()
	} else {
		_ = p.Signal(os.Interrupt)
		time.Sleep(100 * time.Millisecond)
		_ = p.Kill()
	}
	a.cmd = nil
	return nil
}

func (a *App) restartXray() error {
	a.mu.Lock()
	defer a.mu.Unlock()
	_ = a.stopXrayLocked()
	time.Sleep(120 * time.Millisecond)
	return a.startXrayLocked()
}

type sourceMeta struct{ Name, Type string }
type endpoint struct {
	Host string
	Port int
}

func inspectSource(source string) (sourceMeta, endpoint, error) {
	s := strings.TrimSpace(source)
	lower := strings.ToLower(s)
	switch {
	case strings.HasPrefix(lower, "vless://"):
		u, err := url.Parse(s)
		if err != nil {
			return sourceMeta{}, endpoint{}, err
		}
		if u.User == nil || u.User.Username() == "" || u.Hostname() == "" {
			return sourceMeta{}, endpoint{}, errors.New("VLESS 缺少 UUID 或服务器地址")
		}
		p, err := portOf(u, 443)
		if err != nil {
			return sourceMeta{}, endpoint{}, err
		}
		name, _ := url.QueryUnescape(strings.TrimPrefix(u.Fragment, "#"))
		if name == "" {
			name = "VLESS · " + u.Hostname()
		}
		return sourceMeta{Name: name, Type: "VLESS"}, endpoint{Host: u.Hostname(), Port: p}, nil
	case strings.HasPrefix(lower, "trojan://"):
		u, err := url.Parse(s)
		if err != nil {
			return sourceMeta{}, endpoint{}, err
		}
		if u.User == nil || u.User.Username() == "" || u.Hostname() == "" {
			return sourceMeta{}, endpoint{}, errors.New("Trojan 缺少密码或服务器地址")
		}
		p, err := portOf(u, 443)
		if err != nil {
			return sourceMeta{}, endpoint{}, err
		}
		name, _ := url.QueryUnescape(strings.TrimPrefix(u.Fragment, "#"))
		if name == "" {
			name = "Trojan · " + u.Hostname()
		}
		return sourceMeta{Name: name, Type: "Trojan"}, endpoint{Host: u.Hostname(), Port: p}, nil
	case strings.HasPrefix(lower, "vmess://"):
		v, err := decodeVMess(s)
		if err != nil {
			return sourceMeta{}, endpoint{}, err
		}
		if v.Add == "" || v.ID == "" {
			return sourceMeta{}, endpoint{}, errors.New("VMess 缺少服务器地址或 UUID")
		}
		p := intFromAny(v.Port, 443)
		name := strings.TrimSpace(v.PS)
		if name == "" {
			name = "VMess · " + v.Add
		}
		return sourceMeta{Name: name, Type: "VMess"}, endpoint{Host: v.Add, Port: p}, nil
	default:
		var obj map[string]any
		if err := json.Unmarshal([]byte(s), &obj); err != nil {
			return sourceMeta{}, endpoint{}, errors.New("目前支持 VLESS / VMess / Trojan 链接，或完整 Xray JSON")
		}
		ep := endpointFromRaw(obj)
		return sourceMeta{Name: "Xray JSON", Type: "Xray JSON"}, ep, nil
	}
}

func endpointFromRaw(cfg map[string]any) endpoint {
	outs, _ := cfg["outbounds"].([]any)
	for _, o := range outs {
		om, _ := o.(map[string]any)
		st, _ := om["settings"].(map[string]any)
		for _, key := range []string{"vnext", "servers"} {
			arr, _ := st[key].([]any)
			if len(arr) == 0 {
				continue
			}
			first, _ := arr[0].(map[string]any)
			host, _ := first["address"].(string)
			port := intFromAny(first["port"], 0)
			if host != "" && port > 0 {
				return endpoint{Host: host, Port: port}
			}
		}
	}
	return endpoint{}
}

func configFromSource(source string) (map[string]any, error) {
	s := strings.TrimSpace(source)
	if strings.HasPrefix(strings.ToLower(s), "{") {
		var cfg map[string]any
		if err := json.Unmarshal([]byte(s), &cfg); err != nil {
			return nil, fmt.Errorf("Xray JSON 无效: %w", err)
		}
		return cfg, nil
	}
	return configFromLink(s)
}

func baseConfig(outbound map[string]any) map[string]any {
	return map[string]any{
		"log": map[string]any{"loglevel": "warning"},
		"inbounds": []any{map[string]any{
			"tag": "socks-in", "listen": "127.0.0.1", "port": 10808,
			"protocol": "socks", "settings": map[string]any{"auth": "noauth", "udp": true},
		}},
		"outbounds": []any{outbound},
	}
}

func configFromLink(link string) (map[string]any, error) {
	lower := strings.ToLower(link)
	switch {
	case strings.HasPrefix(lower, "vless://"):
		out, err := parseVLESS(link)
		if err != nil {
			return nil, err
		}
		return baseConfig(out), nil
	case strings.HasPrefix(lower, "vmess://"):
		out, err := parseVMess(link)
		if err != nil {
			return nil, err
		}
		return baseConfig(out), nil
	case strings.HasPrefix(lower, "trojan://"):
		out, err := parseTrojan(link)
		if err != nil {
			return nil, err
		}
		return baseConfig(out), nil
	default:
		return nil, errors.New("目前支持 VLESS / VMess / Trojan 链接，或完整 Xray JSON")
	}
}

func parseVLESS(s string) (map[string]any, error) {
	u, err := url.Parse(s)
	if err != nil {
		return nil, err
	}
	if u.User == nil {
		return nil, errors.New("VLESS 缺少 UUID")
	}
	id, host := u.User.Username(), u.Hostname()
	port, err := portOf(u, 443)
	if err != nil {
		return nil, err
	}
	if id == "" || host == "" {
		return nil, errors.New("VLESS 缺少 UUID 或服务器地址")
	}
	q := u.Query()
	user := map[string]any{"id": id, "encryption": value(q, "encryption", "none")}
	if f := q.Get("flow"); f != "" {
		user["flow"] = f
	}
	out := map[string]any{"protocol": "vless", "tag": "proxy", "settings": map[string]any{"vnext": []any{map[string]any{"address": host, "port": port, "users": []any{user}}}}}
	out["streamSettings"] = streamSettings(q)
	return out, nil
}

func parseTrojan(s string) (map[string]any, error) {
	u, err := url.Parse(s)
	if err != nil {
		return nil, err
	}
	if u.User == nil {
		return nil, errors.New("Trojan 缺少密码")
	}
	pass, host := u.User.Username(), u.Hostname()
	port, err := portOf(u, 443)
	if err != nil {
		return nil, err
	}
	if pass == "" || host == "" {
		return nil, errors.New("Trojan 缺少密码或服务器地址")
	}
	q := u.Query()
	out := map[string]any{"protocol": "trojan", "tag": "proxy", "settings": map[string]any{"servers": []any{map[string]any{"address": host, "port": port, "password": pass}}}}
	out["streamSettings"] = streamSettings(q)
	return out, nil
}

type vmessJSON struct {
	V    any    `json:"v"`
	PS   string `json:"ps"`
	Add  string `json:"add"`
	Port any    `json:"port"`
	ID   string `json:"id"`
	Aid  any    `json:"aid"`
	Scy  string `json:"scy"`
	Net  string `json:"net"`
	Type string `json:"type"`
	Host string `json:"host"`
	Path string `json:"path"`
	TLS  string `json:"tls"`
	SNI  string `json:"sni"`
	FP   string `json:"fp"`
	ALPN string `json:"alpn"`
}

func decodeVMess(s string) (vmessJSON, error) {
	raw := strings.TrimPrefix(s, "vmess://")
	b, err := decodeB64(raw)
	if err != nil {
		return vmessJSON{}, fmt.Errorf("VMess Base64 无效: %w", err)
	}
	var v vmessJSON
	if err := json.Unmarshal(b, &v); err != nil {
		return vmessJSON{}, fmt.Errorf("VMess JSON 无效: %w", err)
	}
	return v, nil
}

func parseVMess(s string) (map[string]any, error) {
	v, err := decodeVMess(s)
	if err != nil {
		return nil, err
	}
	if v.Add == "" || v.ID == "" {
		return nil, errors.New("VMess 缺少服务器地址或 UUID")
	}
	port, aid := intFromAny(v.Port, 443), intFromAny(v.Aid, 0)
	sec := v.Scy
	if sec == "" {
		sec = "auto"
	}
	user := map[string]any{"id": v.ID, "alterId": aid, "security": sec}
	out := map[string]any{"protocol": "vmess", "tag": "proxy", "settings": map[string]any{"vnext": []any{map[string]any{"address": v.Add, "port": port, "users": []any{user}}}}}
	q := url.Values{}
	if v.Net != "" {
		q.Set("type", v.Net)
	}
	if v.Host != "" {
		q.Set("host", v.Host)
	}
	if v.Path != "" {
		q.Set("path", v.Path)
	}
	if v.SNI != "" {
		q.Set("sni", v.SNI)
	}
	if v.FP != "" {
		q.Set("fp", v.FP)
	}
	if v.ALPN != "" {
		q.Set("alpn", v.ALPN)
	}
	if strings.EqualFold(v.TLS, "tls") {
		q.Set("security", "tls")
	}
	out["streamSettings"] = streamSettings(q)
	return out, nil
}

func streamSettings(q url.Values) map[string]any {
	network, security := value(q, "type", "tcp"), value(q, "security", "none")
	ss := map[string]any{"network": network, "security": security}
	sni, fp := first(q, "sni", "serverName"), value(q, "fp", "chrome")
	switch security {
	case "tls":
		tls := map[string]any{}
		if sni != "" {
			tls["serverName"] = sni
		}
		if fp != "" {
			tls["fingerprint"] = fp
		}
		if alpn := q.Get("alpn"); alpn != "" {
			tls["alpn"] = splitComma(alpn)
		}
		if q.Get("allowInsecure") == "1" || strings.EqualFold(q.Get("allowInsecure"), "true") {
			tls["allowInsecure"] = true
		}
		ss["tlsSettings"] = tls
	case "reality":
		rs := map[string]any{}
		if sni != "" {
			rs["serverName"] = sni
		}
		if fp != "" {
			rs["fingerprint"] = fp
		}
		if x := first(q, "pbk", "publicKey"); x != "" {
			rs["publicKey"] = x
		}
		if x := first(q, "sid", "shortId"); x != "" {
			rs["shortId"] = x
		}
		if x := first(q, "spx", "spiderX"); x != "" {
			rs["spiderX"] = x
		}
		ss["realitySettings"] = rs
	}
	switch network {
	case "ws":
		ws := map[string]any{"path": value(q, "path", "/")}
		if h := q.Get("host"); h != "" {
			ws["headers"] = map[string]any{"Host": h}
		}
		ss["wsSettings"] = ws
	case "grpc":
		gs := map[string]any{}
		if x := first(q, "serviceName", "path"); x != "" {
			gs["serviceName"] = strings.TrimPrefix(x, "/")
		}
		if x := q.Get("authority"); x != "" {
			gs["authority"] = x
		}
		ss["grpcSettings"] = gs
	case "http", "h2":
		hs := map[string]any{}
		if h := q.Get("host"); h != "" {
			hs["host"] = splitComma(h)
		}
		if p := q.Get("path"); p != "" {
			hs["path"] = p
		}
		ss["httpSettings"], ss["network"] = hs, "http"
	case "xhttp", "splithttp":
		xs := map[string]any{}
		if p := q.Get("path"); p != "" {
			xs["path"] = p
		}
		if h := q.Get("host"); h != "" {
			xs["host"] = h
		}
		if mode := q.Get("mode"); mode != "" {
			xs["mode"] = mode
		}
		ss["xhttpSettings"] = xs
		ss["network"] = "xhttp"
	}
	return ss
}

func portOf(u *url.URL, def int) (int, error) {
	if u.Port() == "" {
		return def, nil
	}
	p, err := strconv.Atoi(u.Port())
	if err != nil || p < 1 || p > 65535 {
		return 0, errors.New("端口无效")
	}
	return p, nil
}
func value(q url.Values, k, d string) string {
	if x := q.Get(k); x != "" {
		return x
	}
	return d
}
func first(q url.Values, keys ...string) string {
	for _, k := range keys {
		if x := q.Get(k); x != "" {
			return x
		}
	}
	return ""
}
func splitComma(s string) []string {
	var out []string
	for _, x := range strings.Split(s, ",") {
		x = strings.TrimSpace(x)
		if x != "" {
			out = append(out, x)
		}
	}
	return out
}
func intFromAny(v any, d int) int {
	switch x := v.(type) {
	case float64:
		return int(x)
	case int:
		return x
	case string:
		if n, e := strconv.Atoi(x); e == nil {
			return n
		}
	}
	return d
}
func decodeB64(s string) ([]byte, error) {
	s = strings.TrimSpace(s)
	for len(s)%4 != 0 {
		s += "="
	}
	if b, e := base64.URLEncoding.DecodeString(s); e == nil {
		return b, nil
	}
	return base64.StdEncoding.DecodeString(s)
}
func newID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err == nil {
		return hex.EncodeToString(b[:])
	}
	return strconv.FormatInt(time.Now().UnixNano(), 36)
}
func tailFile(path string, max int) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	if len(b) > max {
		b = b[len(b)-max:]
	}
	return string(bytes.ToValidUTF8(b, []byte("?")))
}
