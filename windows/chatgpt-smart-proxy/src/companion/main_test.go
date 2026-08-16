package main

import "testing"

func TestVLESS(t *testing.T) {
	c, e := configFromLink("vless://11111111-1111-1111-1111-111111111111@example.com:443?encryption=none&security=reality&sni=www.microsoft.com&fp=chrome&pbk=abc&sid=12&type=tcp#test")
	if e != nil || c["outbounds"] == nil {
		t.Fatalf("%v %#v", e, c)
	}
	m, ep, e := inspectSource("vless://11111111-1111-1111-1111-111111111111@example.com:443?encryption=none&type=tcp#LA")
	if e != nil || m.Name != "LA" || m.Type != "VLESS" || ep.Host != "example.com" || ep.Port != 443 {
		t.Fatalf("meta=%#v ep=%#v err=%v", m, ep, e)
	}
}

func TestTrojan(t *testing.T) {
	if _, e := configFromLink("trojan://pass@example.com:443?security=tls&sni=example.com&type=ws&path=%2Fws&host=example.com"); e != nil {
		t.Fatal(e)
	}
}

func TestVMess(t *testing.T) {
	if _, e := configFromLink("vmess://eyJhZGQiOiJleGFtcGxlLmNvbSIsInBvcnQiOiI0NDMiLCJpZCI6IjExMTExMTExLTExMTEtMTExMS0xMTExLTExMTExMTExMTExMSIsImFpZCI6IjAiLCJuZXQiOiJ3cyIsImhvc3QiOiJleGFtcGxlLmNvbSIsInBhdGgiOiIvd3MiLCJ0bHMiOiJ0bHMiLCJzbmkiOiJleGFtcGxlLmNvbSJ9"); e != nil {
		t.Fatal(e)
	}
}

func TestRawJSON(t *testing.T) {
	raw := `{"inbounds":[{"listen":"127.0.0.1","port":10808,"protocol":"socks"}],"outbounds":[{"protocol":"trojan","settings":{"servers":[{"address":"example.com","port":443,"password":"x"}]}}]}`
	m, ep, err := inspectSource(raw)
	if err != nil || m.Type != "Xray JSON" || ep.Host != "example.com" || ep.Port != 443 {
		t.Fatalf("meta=%#v ep=%#v err=%v", m, ep, err)
	}
	if _, err := configFromSource(raw); err != nil {
		t.Fatal(err)
	}
}

func TestBadVLESSNoPanic(t *testing.T) {
	if _, e := configFromLink("vless://example.com:443"); e == nil {
		t.Fatal("expected error")
	}
}
