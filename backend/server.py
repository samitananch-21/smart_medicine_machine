#!/usr/bin/env python3
"""Local PharmaCare+ demo API. Payments are simulated; no dispensing hardware."""

import argparse
import hashlib
import hmac
import json
import logging
import os
from pathlib import Path
import re
import secrets
import sqlite3
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent
MAX_BODY = 64 * 1024
MAX_MONEY = 100_000_000
SESSION_SECONDS = 8 * 60 * 60
PASSWORD_ITERATIONS = 600_000
LOG = logging.getLogger("pharmacare")


class ApiError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def integer(value, field, minimum=0, maximum=MAX_MONEY):
    # bool is an int in Python, but never a valid JSON money/quantity value.
    if type(value) is not int or not minimum <= value <= maximum:
        raise ApiError(400, f"{field} must be an integer from {minimum} to {maximum}")
    return value


def text_value(value, field, maximum, allow_empty=False):
    if not isinstance(value, str) or len(value) > maximum:
        raise ApiError(400, f"Invalid {field}")
    value = value.strip()
    if not value and not allow_empty:
        raise ApiError(400, f"{field} is required")
    return value


def object_value(value):
    if not isinstance(value, dict):
        raise ApiError(400, "The request body must be a JSON object")
    return value


def password_hash(password, salt):
    return hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), bytes.fromhex(salt), PASSWORD_ITERATIONS
    ).hex()


def product_json(row):
    result = dict(row)
    result["active"] = bool(result["active"])
    return result


def order_json(row):
    result = dict(row)
    result.pop("request_id", None)
    result.pop("body_hash", None)
    result["items"] = json.loads(result["items"])
    return result


class DemoApp:
    def __init__(self, db_path, seed_path, credentials_path, asset_root=None,
                 allowed_origins=None):
        self.db_path = Path(db_path)
        self.asset_root = Path(asset_root or ROOT.parent).resolve()
        self.credentials_path = Path(credentials_path)
        self.allowed_origins = set(allowed_origins or [])
        self.sessions = {}
        self.login_attempts = {}
        self.auth_lock = threading.Lock()
        self.db_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.initialize(Path(seed_path))

    def connect(self):
        db = sqlite3.connect(str(self.db_path), timeout=15)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys = ON")
        return db

    def initialize(self, seed_path):
        db = self.connect()
        try:
            db.execute("PRAGMA journal_mode = WAL")
            db.executescript("""
                CREATE TABLE IF NOT EXISTS metadata (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS products (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    detail TEXT NOT NULL,
                    price_satang INTEGER NOT NULL CHECK(price_satang > 0),
                    image TEXT NOT NULL,
                    category TEXT NOT NULL,
                    warning TEXT,
                    stock INTEGER NOT NULL CHECK(stock >= 0),
                    active INTEGER NOT NULL CHECK(active IN (0, 1)),
                    version INTEGER NOT NULL DEFAULT 1
                );
                CREATE TABLE IF NOT EXISTS admin_users (
                    username TEXT PRIMARY KEY,
                    salt TEXT NOT NULL,
                    password_hash TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS orders (
                    id TEXT PRIMARY KEY,
                    request_id TEXT UNIQUE NOT NULL,
                    body_hash TEXT NOT NULL,
                    status TEXT NOT NULL CHECK(status IN ('pending', 'fulfilled', 'cancelled')),
                    created_at TEXT NOT NULL,
                    payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'qr')),
                    payment_mode TEXT NOT NULL CHECK(payment_mode = 'demo'),
                    subtotal_satang INTEGER NOT NULL,
                    discount_satang INTEGER NOT NULL,
                    total_satang INTEGER NOT NULL,
                    paid_satang INTEGER NOT NULL,
                    change_satang INTEGER NOT NULL,
                    coupon TEXT,
                    items TEXT NOT NULL
                );
            """)
            db.execute("BEGIN IMMEDIATE")
            if not db.execute("SELECT 1 FROM metadata WHERE key = 'seeded'").fetchone():
                with seed_path.open(encoding="utf-8") as source:
                    seed = json.load(source)
                if isinstance(seed, dict):
                    seed = seed["products"]
                if not isinstance(seed, list) or not seed:
                    raise ValueError("seed_products.json must contain a nonempty product list")
                for index, item in enumerate(seed):
                    fields = self.validate_product(item)
                    product_id = text_value(item.get("id", f"med-{index + 1:03d}"), "id", 80)
                    self.insert_product(db, product_id, fields)
                db.execute("INSERT INTO metadata(key, value) VALUES ('seeded', '1')")
            if not db.execute("SELECT 1 FROM admin_users LIMIT 1").fetchone():
                password = secrets.token_urlsafe(18)
                salt = secrets.token_hex(16)
                self.credentials_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                # Only the creating user can read the initial demo password.
                fd = os.open(str(self.credentials_path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
                try:
                    os.fchmod(fd, 0o600)
                    with os.fdopen(fd, "w", encoding="utf-8") as target:
                        target.write(f"username: admin\npassword: {password}\n")
                except Exception:
                    # fdopen normally owns the descriptor, even if write failed.
                    raise
                db.execute("INSERT INTO admin_users VALUES (?, ?, ?)",
                           ("admin", salt, password_hash(password, salt)))
            db.commit()
            os.chmod(self.db_path, 0o600)
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def validate_product(self, data):
        object_value(data)
        name = text_value(data.get("name"), "name", 200)
        detail = text_value(data.get("detail"), "detail", 4000, allow_empty=True)
        price = integer(data.get("price_satang"), "price_satang", 1)
        image = text_value(data.get("image"), "image", 250)
        # The Flutter app bundles these assets; the API does not accept arbitrary URLs/files.
        if not image.startswith("assets/images/") or "\\" in image:
            raise ApiError(400, "image must refer to an existing assets/images/ file")
        image_path = (self.asset_root / image).resolve()
        images_root = (self.asset_root / "assets/images").resolve()
        if images_root not in image_path.parents or not image_path.is_file():
            raise ApiError(400, "Image file does not exist in assets/images/")
        if image_path.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp", ".gif"):
            raise ApiError(400, "Unsupported image file type")
        category = text_value(data.get("category"), "category", 100)
        warning = data.get("warning")
        if warning is not None:
            warning = text_value(warning, "warning", 2000, allow_empty=True) or None
        stock = integer(data.get("stock"), "stock", 0, 1_000_000)
        active = data.get("active", True)
        if type(active) is not bool:
            raise ApiError(400, "active must be a boolean")
        return {"name": name, "detail": detail, "price_satang": price,
                "image": image, "category": category, "warning": warning,
                "stock": stock, "active": int(active)}

    @staticmethod
    def insert_product(db, product_id, fields):
        db.execute("""INSERT INTO products
            (id, name, detail, price_satang, image, category, warning, stock, active, version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)""",
                   (product_id, fields["name"], fields["detail"], fields["price_satang"],
                    fields["image"], fields["category"], fields["warning"], fields["stock"],
                    fields["active"]))

    def origin_allowed(self, origin):
        if origin in self.allowed_origins:
            return True
        try:
            parsed = urlsplit(origin)
            return (parsed.scheme in ("http", "https")
                    and parsed.hostname in ("localhost", "127.0.0.1", "::1")
                    and not parsed.username and not parsed.password
                    and not parsed.path and not parsed.query and not parsed.fragment)
        except ValueError:
            return False

    def login(self, data, peer):
        object_value(data)
        username = text_value(data.get("username"), "username", 100)
        password = text_value(data.get("password"), "password", 500)
        now = time.monotonic()
        # Limit the peer rather than username, so changing the name cannot bypass it.
        with self.auth_lock:
            self.login_attempts = {
                key: [stamp for stamp in stamps if now - stamp < 60]
                for key, stamps in self.login_attempts.items()
                if any(now - stamp < 60 for stamp in stamps)
            }
            attempts = self.login_attempts.setdefault(peer, [])
            if len(attempts) >= 5:
                raise ApiError(429, "Too many login attempts. Try again in one minute.")
            attempts.append(now)
        db = self.connect()
        try:
            row = db.execute("SELECT * FROM admin_users WHERE username = ?", (username,)).fetchone()
        finally:
            db.close()
        # Hash unknown users too, preventing the obvious username timing distinction.
        salt = row["salt"] if row else "00" * 16
        computed = password_hash(password, salt)
        if row is None or not hmac.compare_digest(computed, row["password_hash"]):
            raise ApiError(401, "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง")
        token = secrets.token_urlsafe(32)
        with self.auth_lock:
            self.sessions = {key: value for key, value in self.sessions.items() if value[1] > now}
            self.sessions[token] = (username, now + SESSION_SECONDS)
        return {"token": token, "username": username}

    def authenticate(self, authorization):
        if not authorization or not authorization.startswith("Bearer "):
            raise ApiError(401, "กรุณาเข้าสู่ระบบแอดมิน")
        token = authorization[7:]
        with self.auth_lock:
            session = self.sessions.get(token)
            if not session or session[1] <= time.monotonic():
                self.sessions.pop(token, None)
                raise ApiError(401, "เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง")
        return token

    def list_products(self, admin=False):
        db = self.connect()
        try:
            query = "SELECT * FROM products" + ("" if admin else " WHERE active = 1") + " ORDER BY rowid"
            return {"products": [product_json(row) for row in db.execute(query)]}
        finally:
            db.close()

    def save_product(self, data, product_id=None):
        fields = self.validate_product(data)
        version = integer(data.get("version"), "version", 1, 2_147_483_647) if product_id else None
        db = self.connect()
        try:
            db.execute("BEGIN IMMEDIATE")
            if product_id:
                existing = db.execute("SELECT version FROM products WHERE id = ?", (product_id,)).fetchone()
                if existing is None:
                    raise ApiError(404, "ไม่พบสินค้า")
                if existing["version"] != version:
                    raise ApiError(409, "สินค้าถูกแก้ไขหรือมีการสั่งซื้อแล้ว กรุณาโหลดข้อมูลใหม่")
                db.execute("""UPDATE products SET name=?, detail=?, price_satang=?, image=?,
                    category=?, warning=?, stock=?, active=?, version=version+1 WHERE id=?""",
                           (fields["name"], fields["detail"], fields["price_satang"], fields["image"],
                            fields["category"], fields["warning"], fields["stock"], fields["active"], product_id))
            else:
                product_id = "med-" + secrets.token_hex(8)
                self.insert_product(db, product_id, fields)
            row = db.execute("SELECT * FROM products WHERE id = ?", (product_id,)).fetchone()
            db.commit()
            return {"product": product_json(row)}
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def create_order(self, data):
        object_value(data)
        request_id = text_value(data.get("request_id"), "request_id", 128)
        if not re.fullmatch(r"[A-Za-z0-9._:-]{1,128}", request_id):
            raise ApiError(400, "Invalid request_id")
        items = data.get("items")
        if not isinstance(items, list) or not 1 <= len(items) <= 100:
            raise ApiError(400, "An order must contain 1 to 100 product lines")
        normalized = []
        seen = set()
        for item in items:
            object_value(item)
            product_id = text_value(item.get("product_id"), "product_id", 80)
            if product_id in seen:
                raise ApiError(400, "Duplicate product lines are not allowed")
            seen.add(product_id)
            normalized.append({"product_id": product_id,
                               "quantity": integer(item.get("quantity"), "quantity", 1, 99),
                               "unit_price_satang": integer(item.get("unit_price_satang"), "unit_price_satang", 1)})
        coupon = data.get("coupon")
        if coupon is not None and coupon != "WELCOME10":
            raise ApiError(400, "โค้ดคูปองไม่ถูกต้อง")
        method = data.get("payment_method")
        if method not in ("cash", "qr"):
            raise ApiError(400, "payment_method must be cash or qr")
        paid = integer(data.get("paid_satang"), "paid_satang")
        canonical = {"request_id": request_id, "items": normalized, "coupon": coupon,
                     "payment_method": method, "paid_satang": paid}
        body_hash = hashlib.sha256(json.dumps(canonical, sort_keys=True).encode()).hexdigest()
        db = self.connect()
        try:
            db.execute("BEGIN IMMEDIATE")
            existing = db.execute("SELECT * FROM orders WHERE request_id = ?", (request_id,)).fetchone()
            if existing:
                if existing["body_hash"] != body_hash:
                    raise ApiError(409, "request_id นี้ถูกใช้กับคำสั่งซื้ออื่นแล้ว")
                db.commit()
                return {"order": order_json(existing)}, False
            snapshots = []
            subtotal = 0
            for item in normalized:
                row = db.execute("SELECT * FROM products WHERE id = ?", (item["product_id"],)).fetchone()
                if row is None or not row["active"]:
                    raise ApiError(409, "สินค้านี้ไม่พร้อมจำหน่าย กรุณาโหลดรายการใหม่")
                if row["price_satang"] != item["unit_price_satang"]:
                    raise ApiError(409, f"ราคา {row['name']} เปลี่ยนแล้ว กรุณาโหลดสินค้าใหม่")
                if row["stock"] < item["quantity"]:
                    raise ApiError(409, f"สต็อก {row['name']} ไม่เพียงพอ")
                line_total = row["price_satang"] * item["quantity"]
                subtotal += line_total
                if subtotal > MAX_MONEY:
                    raise ApiError(400, "ยอดคำสั่งซื้อเกินวงเงินเดโม")
                snapshots.append({"product_id": row["id"], "name": row["name"],
                                  "quantity": item["quantity"], "unit_price_satang": row["price_satang"],
                                  "total_satang": line_total})
            discount = (subtotal + 5) // 10 if coupon == "WELCOME10" else 0
            total = subtotal - discount
            if paid < total:
                raise ApiError(400, "จำนวนเงินทดลองยังไม่ครบยอดชำระ")
            if method == "qr" and paid != total:
                raise ApiError(400, "ยอดชำระ QR ทดลองต้องตรงกับยอดคำสั่งซื้อ")
            order_id = "order-" + secrets.token_hex(10)
            created_at = datetime.now(timezone.utc).isoformat()
            db.execute("""INSERT INTO orders
                (id, request_id, body_hash, status, created_at, payment_method, payment_mode,
                 subtotal_satang, discount_satang, total_satang, paid_satang, change_satang, coupon, items)
                VALUES (?, ?, ?, 'pending', ?, ?, 'demo', ?, ?, ?, ?, ?, ?, ?)""",
                       (order_id, request_id, body_hash, created_at, method, subtotal, discount,
                        total, paid, paid - total, coupon, json.dumps(snapshots, ensure_ascii=False)))
            for item in snapshots:
                db.execute("UPDATE products SET stock = stock - ?, version = version + 1 WHERE id = ?",
                           (item["quantity"], item["product_id"]))
            row = db.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
            db.commit()
            return {"order": order_json(row)}, True
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def list_orders(self):
        db = self.connect()
        try:
            return {"orders": [order_json(row) for row in db.execute("SELECT * FROM orders ORDER BY created_at DESC")]}
        finally:
            db.close()

    def update_order(self, order_id, data):
        object_value(data)
        status = data.get("status")
        if status not in ("fulfilled", "cancelled"):
            raise ApiError(400, "status must be fulfilled or cancelled")
        db = self.connect()
        try:
            db.execute("BEGIN IMMEDIATE")
            existing = db.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
            if existing is None:
                raise ApiError(404, "ไม่พบคำสั่งซื้อ")
            if existing["status"] != "pending":
                raise ApiError(409, "คำสั่งซื้อนี้เปลี่ยนสถานะไปแล้ว")
            if status == "cancelled":
                for item in json.loads(existing["items"]):
                    db.execute("UPDATE products SET stock = stock + ?, version = version + 1 WHERE id = ?",
                               (item["quantity"], item["product_id"]))
            db.execute("UPDATE orders SET status = ? WHERE id = ?", (status, order_id))
            row = db.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
            db.commit()
            return {"order": order_json(row)}
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()


class ApiHandler(BaseHTTPRequestHandler):
    server_version = "PharmaCareDemo/1.0"

    def log_message(self, format_string, *args):
        # Avoid putting paths, payloads, bearer tokens or passwords in access logs.
        pass

    def setup(self):
        super().setup()
        self.connection.settimeout(15)

    @property
    def app(self):
        return self.server.app

    def respond(self, status, body):
        payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Vary", "Origin")
        origin = self.headers.get("Origin")
        if origin and self.app.origin_allowed(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.end_headers()
        self.wfile.write(payload)

    def read_body(self):
        if self.headers.get("Transfer-Encoding"):
            raise ApiError(400, "Chunked requests are not supported")
        if self.headers.get_content_type() != "application/json":
            raise ApiError(415, "Content-Type must be application/json")
        length = self.headers.get("Content-Length", "0")
        try:
            length = int(length)
        except ValueError:
            raise ApiError(400, "Invalid Content-Length")
        if length < 0 or length > MAX_BODY:
            raise ApiError(413, "Request body is too large")
        try:
            raw = self.rfile.read(length)
            if len(raw) != length:
                raise ApiError(400, "Incomplete request body")
            return object_value(json.loads(raw.decode("utf-8")))
        except (UnicodeDecodeError, ValueError, RecursionError):
            raise ApiError(400, "Invalid JSON request body")

    def handle_api(self):
        try:
            origin = self.headers.get("Origin")
            if origin and not self.app.origin_allowed(origin):
                raise ApiError(403, "This web origin is not allowed")
            path = urlsplit(self.path).path.rstrip("/")
            if self.command == "OPTIONS":
                if not path.startswith("/api/"):
                    raise ApiError(404, "Not found")
                return self.respond(200, {})
            if self.command == "GET" and path == "/api/health":
                return self.respond(200, {"ok": True})
            if self.command == "GET" and path == "/api/products":
                return self.respond(200, self.app.list_products())
            if self.command == "POST" and path == "/api/admin/login":
                return self.respond(200, self.app.login(self.read_body(), self.client_address[0]))
            if self.command == "POST" and path == "/api/orders":
                body, created = self.app.create_order(self.read_body())
                return self.respond(201 if created else 200, body)
            if path.startswith("/api/admin/"):
                token = self.app.authenticate(self.headers.get("Authorization"))
                if self.command == "POST" and path == "/api/admin/logout":
                    with self.app.auth_lock:
                        self.app.sessions.pop(token, None)
                    return self.respond(200, {})
                if self.command == "GET" and path == "/api/admin/products":
                    return self.respond(200, self.app.list_products(admin=True))
                if self.command == "POST" and path == "/api/admin/products":
                    return self.respond(201, self.app.save_product(self.read_body()))
                if self.command == "PUT" and re.fullmatch(r"/api/admin/products/[A-Za-z0-9_-]+", path):
                    return self.respond(200, self.app.save_product(self.read_body(), path.rsplit("/", 1)[1]))
                if self.command == "GET" and path == "/api/admin/orders":
                    return self.respond(200, self.app.list_orders())
                if self.command == "PATCH" and re.fullmatch(r"/api/admin/orders/[A-Za-z0-9_-]+", path):
                    return self.respond(200, self.app.update_order(path.rsplit("/", 1)[1], self.read_body()))
            raise ApiError(404, "Not found")
        except ApiError as error:
            self.respond(error.status, {"error": str(error)})
        except (BrokenPipeError, ConnectionResetError):
            pass
        except (TimeoutError, OSError):
            # A timed-out/disconnected client should not produce an application traceback.
            self.close_connection = True
        except sqlite3.OperationalError:
            LOG.exception("Database operation failed")
            self.respond(503, {"error": "ฐานข้อมูลไม่พร้อม กรุณาลองอีกครั้ง"})
        except Exception:
            LOG.exception("Unhandled API error")
            self.respond(500, {"error": "เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์"})

    do_GET = handle_api
    do_POST = handle_api
    do_PUT = handle_api
    do_PATCH = handle_api
    do_OPTIONS = handle_api


class DemoServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, app):
        self.app = app
        super().__init__(address, ApiHandler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--db", type=Path, default=ROOT / "data/demo.sqlite3")
    parser.add_argument("--seed", type=Path, default=ROOT / "seed_products.json")
    parser.add_argument("--credentials", type=Path, default=ROOT / "data/demo_credentials.txt")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    app = DemoApp(args.db, args.seed, args.credentials,
                  allowed_origins=[value.strip() for value in os.environ.get("DEMO_ALLOWED_ORIGINS", "").split(",") if value.strip()])
    server = DemoServer((args.host, args.port), app)
    print(f"PharmaCare+ DEMO API: http://{args.host}:{args.port}/api", flush=True)
    print(f"Admin credentials file: {args.credentials} (password is never logged)", flush=True)
    print("Simulated payments only. No real payment verification or medicine dispensing.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
