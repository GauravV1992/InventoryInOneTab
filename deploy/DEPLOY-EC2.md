# InventoryInOneTap — Amazon EC2 Linux hosting

Complete production setup for **EC2 app server** `13.205.231.60` with **SQL Server** on `43.205.62.168`.

## Architecture

```
Browser  →  Nginx (80/443) on EC2 13.205.231.60
                ├── /          → React build (frontend/dist)
                └── /api/*     → Node.js Express :5000 (PM2)
                                      ↓
                               SQL Server 43.205.62.168:1433
```

---

## Part 1 — AWS security groups

### EC2 app server (`13.205.231.60`)

| Port | Protocol | Source        | Purpose        |
|------|----------|---------------|----------------|
| 22   | TCP      | Your IP only  | SSH            |
| 80   | TCP      | 0.0.0.0/0     | HTTP           |
| 443  | TCP      | 0.0.0.0/0     | HTTPS (later)  |

Do **not** open port 5000 publicly — Nginx proxies to it locally.

### SQL Server EC2 (`43.205.62.168`)

| Port | Protocol | Source           | Purpose     |
|------|----------|------------------|-------------|
| 1433 | TCP      | `13.205.231.60`  | App → SQL   |

On the SQL Server machine, also ensure:

- SQL Server listens on TCP 1433 (SQL Server Configuration Manager)
- Windows Firewall allows inbound 1433 from `13.205.231.60`
- SQL login `DomachLogin` (or your user) has access to database `PawanPutra`

Test from app server after setup:

```bash
nc -zv 43.205.62.168 1433
```

---

## Part 2 — Connect to EC2

```bash
ssh -i your-key.pem ec2-user@13.205.231.60
```

Amazon Linux 2023 uses user `ec2-user`. Ubuntu uses `ubuntu`.

---

## Part 3 — Install system packages

### Amazon Linux 2023

```bash
sudo dnf update -y
sudo dnf install -y git nginx

# Node.js 20 LTS
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs
node -v   # v20.x
npm -v

# PM2 process manager
sudo npm install -g pm2
```

### Amazon Linux 2 (if older AMI)

```bash
sudo yum update -y
sudo amazon-linux-extras install nginx1 -y
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs git
sudo npm install -g pm2
```

Enable services:

```bash
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## Part 4 — Upload project to server

### Option A — Git (recommended)

```bash
sudo mkdir -p /opt/inventoryinonetap
sudo chown ec2-user:ec2-user /opt/inventoryinonetap
cd /opt/inventoryinonetap
git clone <your-repo-url> .
```

### Option B — SCP from your PC

```powershell
scp -i your-key.pem -r C:\Users\Admin\source\repos\Python\PawanPutra ec2-user@13.205.231.60:/opt/inventoryinonetap
```

On server:

```bash
sudo chown -R ec2-user:ec2-user /opt/inventoryinonetap
```

---

## Part 5 — Backend `.env` (production)

```bash
cd /opt/inventoryinonetap/backend
cp .env.example .env
nano .env
```

Use:

```env
DB_SERVER=43.205.62.168
DB_DATABASE=PawanPutra
DB_USER=DomachLogin
DB_PASSWORD=your_sql_password
DB_PORT=1433

JWT_SECRET=your_128_char_random_secret_here
PORT=5000
NODE_ENV=production

# Same origin via Nginx — use your public URL
FRONTEND_URL=http://13.205.231.60

RAZORPAY_KEY_ID=rzp_live_xxxxx
RAZORPAY_KEY_SECRET=your_razorpay_secret
```

Generate JWT secret on server:

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

Install backend deps:

```bash
cd /opt/inventoryinonetap/backend
npm install --omit=dev
```

Test API once:

```bash
node server.js
# Should print: Database connected: 43.205.62.168:1433 / PawanPutra
# Ctrl+C to stop
```

---

## Part 6 — Build frontend

```bash
cd /opt/inventoryinonetap/frontend
npm install
npm run build
```

Output goes to `frontend/dist/`. The app calls `/api` (same host) — no code change needed.

---

## Part 7 — PM2 (keep API running)

```bash
cd /opt/inventoryinonetap
pm2 start deploy/ecosystem.config.cjs
pm2 save
pm2 startup
# Run the command PM2 prints (sudo env PATH=...)
pm2 status
```

Logs:

```bash
pm2 logs inventory-api
```

Health check:

```bash
curl http://127.0.0.1:5000/api/health
```

---

## Part 8 — Nginx

```bash
sudo cp /opt/inventoryinonetap/deploy/nginx-inventoryinonetap.conf /etc/nginx/conf.d/inventoryinonetap.conf
sudo nginx -t
sudo systemctl reload nginx
```

Open in browser:

**http://13.205.231.60**

Login with your app credentials (not the old default if you changed them).

---

## Part 9 — Domain + HTTPS (inventoryinonetap.com)

1. Point DNS **A records** for `@` and `www` → your EC2 public IP (already: `13.205.231.60`)
2. On EC2, open **Security Group** inbound **TCP 443** (HTTPS) from `0.0.0.0/0` (and keep 80 open for Certbot)
3. SSH in and run:

   ```bash
   cd /opt/inventoryinonetap
   # upload latest deploy/install-https.sh if needed, then:
   bash deploy/install-https.sh
   ```

   Or manually:

   ```bash
   sudo dnf install -y certbot python3-certbot-nginx
   sudo cp /opt/inventoryinonetap/deploy/nginx-inventoryinonetap.conf /etc/nginx/conf.d/inventoryinonetap.conf
   sudo nginx -t && sudo systemctl reload nginx
   sudo certbot --nginx -d inventoryinonetap.com -d www.inventoryinonetap.com
   ```

4. Ensure `backend/.env` has:

   ```env
   SITE_DOMAIN=inventoryinonetap.com
   SITE_URL=https://inventoryinonetap.com
   SUPPORT_EMAIL=support@inventoryinonetap.com
   FRONTEND_URL=https://inventoryinonetap.com,https://www.inventoryinonetap.com
   ```

5. Restart API:

   ```bash
   pm2 restart inventory-api
   ```

Certbot auto-renews via systemd timer. Test: https://inventoryinonetap.com

---

## Part 10 — SQL scripts (if not already applied)

Run in SSMS on `43.205.62.168` in this order:

1. `fix_user_account.sql`
2. `fix_multi_company.sql`
3. `fix_subscription_users.sql`
4. `fix_plans_3tier.sql`
5. `fix_user_prorated_payment.sql`
6. `fix_payment_invoices.sql`
7. `fix_plan_enforcement.sql`
8. `fix_india_datetime.sql`
9. `fix_company_reference_numbers.sql`
10. `fix_company_stock.sql`
11. `fix_register_trial.sql`
12. `fix_standard_500_materials.sql`
13. `fix_indexes_and_foreign_keys.sql`

---

## Deploy updates (after code changes)

```bash
cd /opt/inventoryinonetap
git pull   # or re-upload files

cd backend && npm install --omit=dev
cd ../frontend && npm install && npm run build

pm2 restart inventory-api
sudo systemctl reload nginx
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Site not loading | `sudo systemctl status nginx` — check security group port 80 |
| 502 Bad Gateway | `pm2 status` — API not running; `pm2 logs inventory-api` |
| Database error on login | Test `nc -zv 43.205.62.168 1433`; check SQL SG + credentials in `.env` |
| **Origin not allowed** on login | Redeploy `backend/security.js` + `backend/site.js`, then `pm2 restart inventory-api`. Domain, www, IP, and localhost are always allowed. If it still fails, check `pm2 logs inventory-api` for `CORS blocked origin:` |
| JWT / session issues | Strong `JWT_SECRET` set; `pm2 restart inventory-api` after change |
| Payment fails | Razorpay keys in `.env`; live keys need HTTPS domain |

---

## Quick verification checklist

- [ ] http://13.205.231.60 loads login page
- [ ] `curl http://13.205.231.60/api/health` returns `{"status":"ok"}`
- [ ] Login works
- [ ] Materials / purchase / sales work
- [ ] PM2 shows `inventory-api` online: `pm2 status`
- [ ] SQL port open from app server only (not public 1433)

---

## Security reminders

- Never commit `.env` to git
- Restrict SSH (port 22) to your office/home IP
- Use strong `JWT_SECRET` and SQL password
- Keep `RAZORPAY_KEY_SECRET` server-side only
- Enable HTTPS before going live with payments
