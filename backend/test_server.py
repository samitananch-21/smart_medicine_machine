"""HTTP integration tests; isolated SQLite databases, no running server needed."""

from concurrent.futures import ThreadPoolExecutor
import copy
import http.client
import json
from pathlib import Path
import stat
import tempfile
import threading
import time
import unittest

from backend.server import DemoApp, DemoServer, MAX_BODY


class DemoApiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.seed_path = self.root / "seed.json"
        self.credentials_path = self.root / "credentials.txt"
        self.db_path = self.root / "demo.sqlite3"
        self.seed = [
            {"id": "p001", "name": "Paracetamol", "detail": "Demo product", "price_satang": 2500,
             "image": "assets/images/para.png", "category": "ยาและบรรเทาอาการ",
             "warning": None, "stock": 3, "active": True},
            {"id": "p002", "name": "Water", "detail": "Demo product", "price_satang": 105,
             "image": "assets/images/water.png", "category": "เครื่องดื่ม",
             "warning": None, "stock": 20, "active": True},
        ]
        self.seed_path.write_text(json.dumps(self.seed), encoding="utf-8")
        self.app = DemoApp(self.db_path, self.seed_path, self.credentials_path)
        self.httpd = DemoServer(("127.0.0.1", 0), self.app)
        self.thread = threading.Thread(target=self.httpd.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_server)
        self.password = self.credentials_path.read_text().split("password: ", 1)[1].strip()
        self.token = None

    def stop_server(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=2)

    def request(self, method, path, payload=None, token=None, headers=None, raw=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.httpd.server_port, timeout=10)
        request_headers = dict(headers or {})
        if token:
            request_headers["Authorization"] = "Bearer " + token
        if raw is not None:
            body = raw
        elif payload is not None:
            body = json.dumps(payload).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")
        else:
            body = None
        try:
            connection.request(method, "/api" + path, body=body, headers=request_headers)
            response = connection.getresponse()
            return response.status, json.loads(response.read()), dict(response.getheaders())
        finally:
            connection.close()

    def login(self):
        status, body, _ = self.request("POST", "/admin/login", {"username": "admin", "password": self.password})
        self.assertEqual(status, 200, body)
        self.token = body["token"]
        return self.token

    def product(self, product_id="p001"):
        status, body, _ = self.request("GET", "/products")
        self.assertEqual(status, 200)
        return next(product for product in body["products"] if product["id"] == product_id)

    def order_payload(self, request_id="test-1", quantity=1, product_id="p001", price=2500, paid=2500, **kwargs):
        return {"request_id": request_id,
                "items": [{"product_id": product_id, "quantity": quantity, "unit_price_satang": price}],
                "coupon": None, "payment_method": "cash", "paid_satang": paid, **kwargs}

    def test_health_credentials_and_admin_routes_require_auth(self):
        self.assertEqual(self.request("GET", "/health")[:2], (200, {"ok": True}))
        mode = stat.S_IMODE(self.credentials_path.stat().st_mode)
        self.assertEqual(mode, 0o600)
        self.assertGreaterEqual(len(self.password), 20)
        with self.app.connect() as db:
            row = db.execute("SELECT * FROM admin_users").fetchone()
            self.assertNotEqual(row["password_hash"], self.password)
            self.assertGreater(len(row["salt"]), 20)
        routes = [("GET", "/admin/products"), ("POST", "/admin/products"),
                  ("PUT", "/admin/products/p001"), ("GET", "/admin/orders"),
                  ("PATCH", "/admin/orders/missing"), ("POST", "/admin/logout")]
        for method, path in routes:
            with self.subTest(method=method, path=path):
                status, body, _ = self.request(method, path, {})
                self.assertEqual(status, 401)
                self.assertIn("error", body)
        token = self.login()
        self.assertEqual(self.request("GET", "/admin/products", token=token)[0], 200)
        self.assertEqual(self.request("POST", "/admin/logout", {}, token)[0], 200)
        self.assertEqual(self.request("GET", "/admin/products", token=token)[0], 401)

    def test_login_throttling_and_session_expiry(self):
        token = self.login()
        self.app.sessions[token] = ("admin", time.monotonic() - 1)
        self.assertEqual(self.request("GET", "/admin/orders", token=token)[0], 401)
        for _ in range(4):
            self.assertEqual(self.request("POST", "/admin/login", {"username": "admin", "password": "wrong"})[0], 401)
        self.assertEqual(self.request("POST", "/admin/login", {"username": "other", "password": "wrong"})[0], 429)

    def test_edit_product_persists_and_conflict_prevents_overwrite(self):
        token = self.login()
        before = self.product()
        updated = {**before, "price_satang": 3500, "stock": 7, "warning": "Demo warning"}
        status, body, _ = self.request("PUT", "/admin/products/p001", updated, token)
        self.assertEqual(status, 200, body)
        self.assertEqual(body["product"]["version"], 2)
        self.assertEqual(self.request("PUT", "/admin/products/p001", updated, token)[0], 409)
        password_before = self.credentials_path.read_text()
        # Seed edits and restarting must not replace existing products/admin password.
        self.seed_path.unlink()
        restarted = DemoApp(self.db_path, self.seed_path, self.credentials_path)
        product = restarted.list_products()["products"][0]
        self.assertEqual((product["price_satang"], product["stock"], product["warning"]), (3500, 7, "Demo warning"))
        self.assertEqual(self.credentials_path.read_text(), password_before)

    def test_product_validation_and_hidden_products(self):
        token = self.login()
        product = self.product()
        invalid = [("price_satang", -1), ("price_satang", 0), ("price_satang", True),
                   ("price_satang", 12.5), ("price_satang", 100_000_001),
                   ("stock", -1), ("active", 1), ("name", ""),
                   ("image", "assets/images/missing.png"), ("image", "assets/images/../../pubspec.yaml")]
        for field, value in invalid:
            with self.subTest(field=field, value=value):
                status, _, _ = self.request("PUT", "/admin/products/p001", {**product, field: value}, token)
                self.assertEqual(status, 400)
        self.assertEqual(self.product()["version"], 1)
        status, body, _ = self.request("POST", "/admin/products", {**self.seed[1], "name": "New item", "active": False}, token)
        self.assertEqual(status, 201, body)
        self.assertFalse(body["product"]["active"])
        new_id = body["product"]["id"]
        self.assertEqual(len(self.request("GET", "/products")[1]["products"]), 2)
        self.assertEqual(len(self.request("GET", "/admin/products", token=token)[1]["products"]), 3)
        self.assertEqual(self.request("POST", "/orders", self.order_payload(product_id=new_id, price=105))[0], 409)

    def test_authoritative_prices_stock_payment_and_atomic_failures(self):
        invalid_orders = [
            (self.order_payload(price=1), 409),
            (self.order_payload(quantity=4, paid=10000), 409),
            (self.order_payload(paid=2499), 400),
            (self.order_payload(paid=2600, payment_method="qr"), 400),
            (self.order_payload(quantity=0), 400),
            (self.order_payload(quantity=True), 400),
            (self.order_payload(quantity=100), 400),
            (self.order_payload(paid=-1), 400),
            (self.order_payload(paid=1.5), 400),
            (self.order_payload(coupon="INVALID"), 400),
        ]
        for payload, expected in invalid_orders:
            with self.subTest(payload=payload):
                self.assertEqual(self.request("POST", "/orders", payload)[0], expected)
        payload = self.order_payload(paid=10000)
        payload["items"].append({"product_id": "does-not-exist", "quantity": 1, "unit_price_satang": 1})
        self.assertEqual(self.request("POST", "/orders", payload)[0], 409)
        duplicate = self.order_payload(paid=5000)
        duplicate["items"].append(copy.deepcopy(duplicate["items"][0]))
        self.assertEqual(self.request("POST", "/orders", duplicate)[0], 400)
        self.assertEqual(self.product()["stock"], 3)
        self.assertEqual(self.app.list_orders(), {"orders": []})

    def test_checkout_change_discount_rounding_and_order_snapshot(self):
        token = self.login()
        payload = self.order_payload(product_id="p002", price=105, paid=100, coupon="WELCOME10")
        status, body, _ = self.request("POST", "/orders", payload)
        self.assertEqual(status, 201, body)
        order = body["order"]
        self.assertEqual(order["payment_mode"], "demo")
        self.assertEqual(order["status"], "pending")
        self.assertEqual((order["subtotal_satang"], order["discount_satang"], order["total_satang"], order["change_satang"]), (105, 11, 94, 6))
        self.assertEqual(self.product("p002")["stock"], 19)
        self.assertEqual(self.product("p002")["version"], 2)
        changed = {**self.product("p002"), "name": "Renamed", "price_satang": 400}
        self.assertEqual(self.request("PUT", "/admin/products/p002", changed, token)[0], 200)
        stored = self.request("GET", "/admin/orders", token=token)[1]["orders"][0]
        self.assertEqual(stored["items"][0]["name"], "Water")
        self.assertEqual(stored["items"][0]["unit_price_satang"], 105)
        self.assertNotIn("body_hash", stored)

    def test_order_persistence_and_idempotency(self):
        payload = self.order_payload()
        status, body, _ = self.request("POST", "/orders", payload)
        self.assertEqual(status, 201)
        repeated = self.request("POST", "/orders", payload)
        self.assertEqual(repeated[0], 200)
        self.assertEqual(repeated[1], body)
        self.assertEqual(self.request("POST", "/orders", {**payload, "paid_satang": 5000})[0], 409)
        self.assertEqual(self.product()["stock"], 2)
        restarted = DemoApp(self.db_path, self.seed_path, self.credentials_path)
        repeated_body, created = restarted.create_order(payload)
        self.assertFalse(created)
        self.assertEqual(repeated_body, body)
        self.assertEqual(len(restarted.list_orders()["orders"]), 1)

    def test_concurrent_duplicate_orders_deduct_once(self):
        barrier = threading.Barrier(2)
        payload = self.order_payload()

        def checkout():
            barrier.wait(timeout=5)
            return self.request("POST", "/orders", payload)

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(checkout) for _ in range(2)]
            results = [future.result(timeout=10) for future in futures]
        self.assertEqual(sorted(result[0] for result in results), [200, 201])
        self.assertEqual(results[0][1]["order"]["id"], results[1][1]["order"]["id"])
        self.assertEqual(self.product()["stock"], 2)
        self.assertEqual(len(self.app.list_orders()["orders"]), 1)

    def test_concurrent_buyers_cannot_oversell(self):
        barrier = threading.Barrier(2)

        def checkout(index):
            barrier.wait(timeout=5)
            return self.request("POST", "/orders", self.order_payload(request_id=f"concurrent-{index}", quantity=2, paid=5000))

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(checkout, index) for index in range(2)]
            results = [future.result(timeout=10) for future in futures]
        self.assertEqual(sorted(result[0] for result in results), [201, 409])
        self.assertEqual(self.product()["stock"], 1)
        self.assertEqual(len(self.app.list_orders()["orders"]), 1)

    def test_cancel_restocks_once_and_fulfilled_cannot_cancel(self):
        token = self.login()
        body = self.request("POST", "/orders", self.order_payload())[1]
        order_id = body["order"]["id"]
        path = f"/admin/orders/{order_id}"
        self.assertEqual(self.request("PATCH", path, {"status": "cancelled"}, token)[0], 200)
        self.assertEqual(self.product()["stock"], 3)
        self.assertEqual(self.request("PATCH", path, {"status": "cancelled"}, token)[0], 409)
        self.assertEqual(self.request("PATCH", path, {"status": "fulfilled"}, token)[0], 409)
        self.assertEqual(self.product()["stock"], 3)
        body = self.request("POST", "/orders", self.order_payload(request_id="second"))[1]
        path = f"/admin/orders/{body['order']['id']}"
        self.assertEqual(self.request("PATCH", path, {"status": "fulfilled"}, token)[0], 200)
        self.assertEqual(self.request("PATCH", path, {"status": "cancelled"}, token)[0], 409)
        self.assertEqual(self.product()["stock"], 2)

    def test_cors_and_request_limits(self):
        allowed_origin = "http://localhost:51872"
        response = self.request("OPTIONS", "/products", headers={"Origin": allowed_origin})
        self.assertEqual(response[0], 200)
        self.assertEqual(response[2]["Access-Control-Allow-Origin"], allowed_origin)
        for origin in ("https://example.com", "null", "http://localhost.evil.com:1234"):
            with self.subTest(origin=origin):
                response = self.request("POST", "/orders", self.order_payload(), headers={"Origin": origin})
                self.assertEqual(response[0], 403)
                self.assertNotIn("Access-Control-Allow-Origin", response[2])
        self.assertEqual(self.product()["stock"], 3)
        lan_origin = "http://192.168.1.20:8080"
        self.app.allowed_origins.add(lan_origin)
        response = self.request("GET", "/products", headers={"Origin": lan_origin})
        self.assertEqual(response[2]["Access-Control-Allow-Origin"], lan_origin)
        response = self.request("POST", "/orders", raw=b"{" , headers={"Content-Type": "application/json"})
        self.assertEqual(response[0], 400)
        response = self.request("POST", "/orders", raw=b"{}", headers={"Content-Type": "text/plain"})
        self.assertEqual(response[0], 415)
        response = self.request("POST", "/orders", raw=b"x" * (MAX_BODY + 1), headers={"Content-Type": "application/json"})
        self.assertEqual(response[0], 413)


if __name__ == "__main__":
    unittest.main()
