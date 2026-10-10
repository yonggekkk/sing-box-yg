"""在临时目录中验证 sb 原始导出函数，避免执行安装和服务管理逻辑。"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


parser = argparse.ArgumentParser()
parser.add_argument("script", type=Path)
parser.add_argument("--mihomo", type=Path)
parser.add_argument("--mihomo-data-dir", type=Path)
args = parser.parse_args()
if args.mihomo and not args.mihomo_data_dir:
    parser.error("--mihomo 需要 --mihomo-data-dir")
source = args.script.read_text()


class ExportTests(unittest.TestCase):
    def export(self, override=None, tls=False, tunnel="temporary", version="1.13", server_name="origin.example.com", overrides=None):
        with tempfile.TemporaryDirectory(prefix="sb-export-test-") as tmp:
            root = Path(tmp)
            box = root / "box"
            box.mkdir()
            ca = root / "ca"
            ca.mkdir()
            uuid = "11111111-2222-4333-8444-555555555555"
            inbounds = [
                {"listen_port": 41817, "users": [{"uuid": uuid}], "tls": {
                    "server_name": "apple.com", "reality": {"short_id": ["abcd1234"]}}},
                {"listen_port": 2095, "tls": {"enabled": tls, "server_name": server_name},
                 "transport": {"path": "/test-vm"}},
            ]
            inbounds += [{"listen_port": port, "tls": {"key_path": str(box / "private.key")}}
                         for port in (23637, 17286, 54162)]
            (box / "sb.json").write_text(json.dumps({"inbounds": inbounds}))
            for name, value in {
                "server_ip.log": "192.0.2.1", "server_ipcl.log": "192.0.2.1",
                "public.key": "scicrYMZHumDmuyUPI5eD1VR9EwgFToR43Aia1VogRU",
                "argo.log": "https://first.trycloudflare.com\nhttps://test.trycloudflare.com\n",
            }.items():
                (box / name).write_text(value)
            custom_values = overrides or {}
            if overrides is None and override is not None:
                custom_values = {name: override for name in
                                 ("cfvmadd_local.txt", "cfymjx.txt", "cfvmadd_argo.txt")}
            for name, value in custom_values.items():
                (box / name).write_text(value)
            result = source[source.index("result_vl_vm_hy_tu(){"):source.index("\nresvless(){")]
            client = source[source.index("sb_client(){"):source.index("\ncfargo_ym(){")]
            functions = (result + client).replace("/etc/s-box", str(box)).replace("/root/ygkkkca", str(ca))
            ps_output = {
                "temporary": "cloudflared tunnel --url http://localhost:2095",
                "fixed": "cloudflared tunnel run",
                "both": "cloudflared tunnel --url http://localhost:2095\ncloudflared tunnel run",
                "none": "",
            }[tunnel]
            harness = root / "export.sh"
            harness.write_text(functions + '''
iptables(){ :; }
openssl(){ :; }
ps(){ printf '%s\\n' "$SB_TEST_PS"; }
hostname=test
argogd=fixed.example.com
sbnh="$SB_TEST_VERSION"
result_vl_vm_hy_tu
sb_client
''')
            proc = subprocess.run(["bash", str(harness)], capture_output=True, text=True,
                                  env={**os.environ, "SB_TEST_PS": ps_output, "SB_TEST_VERSION": version})
            self.assertEqual(proc.returncode, 0, proc.stderr)
            if args.mihomo:
                validation = subprocess.run(
                    [str(args.mihomo), "-t", "-d", str(args.mihomo_data_dir), "-f", str(box / "clmi.yaml")],
                    capture_output=True, text=True, timeout=30)
                self.assertEqual(validation.returncode, 0, validation.stdout + validation.stderr)
            config = yaml.safe_load((box / "clmi.yaml").read_text())
            json_config = json.loads((box / "sbox.json").read_text())
            return config, json_config

    def assert_valid_nodes(self, config):
        names = [p["name"] for p in config["proxies"]]
        self.assertEqual(len(names), len(set(names)))
        for proxy in config["proxies"]:
            self.assertIsInstance(proxy["server"], str, proxy["name"])
            self.assertTrue(proxy["server"].strip(), proxy["name"])
            if proxy.get("network") == "ws":
                self.assertIsInstance(proxy["ws-opts"]["headers"]["Host"], str, proxy["name"])
                self.assertTrue(proxy["ws-opts"]["headers"]["Host"].strip(), proxy["name"])
        allowed = set(names) | {g["name"] for g in config["proxy-groups"]} | {"DIRECT", "REJECT"}
        for group in config["proxy-groups"]:
            self.assertTrue(set(group["proxies"]) <= allowed)

    def test_empty_overrides_fall_back_to_defaults(self):
        for value in ("", "\n", " \t\n"):
            with self.subTest(value=repr(value)):
                config, _ = self.export(override=value)
                self.assert_valid_nodes(config)
                vmess = next(p for p in config["proxies"] if p["name"] == "vmess-ws-test")
                self.assertEqual(vmess["server"], "192.0.2.1")
                self.assertEqual(vmess["ws-opts"]["headers"]["Host"], "origin.example.com")
        for name in ("cfvmadd_local.txt", "cfymjx.txt", "cfvmadd_argo.txt"):
            for value in ("", "\n", " \t\n"):
                with self.subTest(file=name, value=repr(value)):
                    config, _ = self.export(overrides={name: value})
                    self.assert_valid_nodes(config)
                    vmess = next(p for p in config["proxies"] if p["name"] == "vmess-ws-test")
                    self.assertEqual(vmess["server"], "192.0.2.1")
                    self.assertEqual(vmess["ws-opts"]["headers"]["Host"], "origin.example.com")
                    for proxy in config["proxies"]:
                        if "argo" in proxy["name"]:
                            self.assertEqual(proxy["server"], "cloudflare-ech.com")

    def test_explicit_overrides_are_preserved(self):
        config, _ = self.export(override="cdn.example.com")
        self.assert_valid_nodes(config)
        vmess = next(p for p in config["proxies"] if p["name"] == "vmess-ws-test")
        self.assertEqual(vmess["server"], "cdn.example.com")
        self.assertEqual(vmess["ws-opts"]["headers"]["Host"], "cdn.example.com")
        for name in ("cfvmadd_local.txt", "cfymjx.txt", "cfvmadd_argo.txt"):
            with self.subTest(file=name):
                config, json_config = self.export(overrides={name: "custom.example.com"})
                self.assert_valid_nodes(config)
                vmess = next(p for p in config["proxies"] if p["name"] == "vmess-ws-test")
                expected_server = "custom.example.com" if name == "cfvmadd_local.txt" else "192.0.2.1"
                expected_host = "custom.example.com" if name == "cfymjx.txt" else "origin.example.com"
                self.assertEqual(vmess["server"], expected_server)
                self.assertEqual(vmess["ws-opts"]["headers"]["Host"], expected_host)
                direct = next(p for p in json_config["outbounds"] if p.get("tag") == "vmess-test")
                self.assertEqual(direct["server"], expected_server)
                self.assertEqual(direct["transport"]["headers"]["Host"], [expected_host])

    def test_all_tunnel_branches_and_legacy_core(self):
        for tunnel in ("temporary", "fixed", "both", "none"):
            for version in ("1.10", "1.13"):
                with self.subTest(tunnel=tunnel, version=version):
                    config, _ = self.export(tunnel=tunnel, version=version)
                    self.assert_valid_nodes(config)
                    argo_names = [p["name"] for p in config["proxies"] if "argo" in p["name"]]
                    expected_count = {"temporary": 2, "fixed": 2, "both": 4, "none": 0}[tunnel]
                    self.assertEqual(len(argo_names), expected_count)
                    if tunnel == "fixed":
                        self.assertTrue(all("固定" in name for name in argo_names))

    def test_dns_policy_is_not_emitted_at_root(self):
        config, _ = self.export()
        self.assertNotIn("nameserver-policy", config)

    def test_missing_server_name_uses_vmess_address_for_host(self):
        config, _ = self.export(server_name=None)
        self.assert_valid_nodes(config)
        vmess = next(p for p in config["proxies"] if p["name"] == "vmess-ws-test")
        self.assertEqual(vmess["ws-opts"]["headers"]["Host"], "192.0.2.1")

    def test_tls_vmess_defaults_are_preserved(self):
        config, _ = self.export(tls=True, override="\n")
        self.assert_valid_nodes(config)
        vmess = next(p for p in config["proxies"] if p["name"] == "vmess-ws-test")
        self.assertTrue(vmess["tls"])
        self.assertEqual(vmess["server"], "origin.example.com")

    def test_tls_custom_address_preserves_host_and_server_name(self):
        config, json_config = self.export(tls=True, overrides={
            "cfvmadd_local.txt": "cdn.example.com",
            "cfymjx.txt": "custom-host.example.com",
            "cfvmadd_argo.txt": "argo.example.com",
        })
        self.assert_valid_nodes(config)
        vmess = next(p for p in config["proxies"] if p["name"] == "vmess-ws-test")
        self.assertEqual(vmess["server"], "cdn.example.com")
        self.assertEqual(vmess["servername"], "origin.example.com")
        self.assertEqual(vmess["ws-opts"]["headers"]["Host"], "origin.example.com")
        direct = next(p for p in json_config["outbounds"] if p.get("tag") == "vmess-test")
        self.assertEqual(direct["server"], "cdn.example.com")
        self.assertEqual(direct["tls"]["server_name"], "origin.example.com")
        self.assertEqual(direct["transport"]["headers"]["Host"], ["origin.example.com"])


if __name__ == "__main__":
    unittest.main(argv=["test_sb_export.py"], verbosity=2)
