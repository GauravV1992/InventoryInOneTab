# InventoryInOneTap — Retailer Inventory System

Modern React + Node.js + SQL Server inventory management for a single retailer.

## Features

| Module | Description |
|--------|-------------|
| **Material Master** | MaterialName, Color, HSNCode, Rate, Unit, Remark |
| **Warehouse Locations** | Manage stock warehouse locations |
| **Opening Stock** | Initial stock with location dropdown |
| **Purchase Inward** | Stock IN with location selection |
| **Sales** | Stock OUT with location + stock validation |
| **Stock Report** | Current stock summary + transaction ledger |

**Login:** `admin` / `welcome123`

---

## Step 1 — Run Database Script (Manual)

1. Open **SQL Server Management Studio (SSMS)**
2. Open file: `database/PawanPutra.sql`
3. Execute the full script

This creates:
- Database: **PawanPutra** (internal SQL Server database name)
- Tables: Users, MaterialMaster, WarehouseLocation, OpeningStock, PurchaseInward, Sales, StockLedger
- Views: `vw_StockSummary`, `vw_StockReport`, `vw_MaterialStockByLocation`
- Stored Procedures for all CRUD and stock operations
- Sample warehouse locations

---

## Step 2 — Configure Backend

```powershell
cd backend
copy .env.example .env
```

Edit `.env` with your SQL Server credentials:

```env
DB_SERVER=localhost
DB_DATABASE=PawanPutra
DB_USER=sa
DB_PASSWORD=YourPassword123
DB_PORT=1433
JWT_SECRET=InventoryInOneTap_SecretKey_2026
PORT=5000
```

Start API:

```powershell
npm install
npm start
```

API runs at: `http://localhost:5000`

---

## Step 3 — Start React Frontend

```powershell
cd frontend
npm install
npm run dev
```

App runs at: `http://localhost:5173`

---

## Project Structure

```
InventoryInOneTap/
├── database/
│   └── PawanPutra.sql       ← Execute manually in SSMS
├── backend/
│   ├── server.js            ← Express REST API
│   ├── db.js                ← SQL Server connection
│   └── .env.example
└── frontend/
    └── src/
        ├── pages/           ← All UI pages
        ├── components/      ← Layout, UI components
        └── api.js           ← API client
```

---

## Stock Flow

```
Opening Stock  →  Stock IN (Purchase)  →  Stock OUT (Sales)
       ↓                  ↓                      ↓
              StockLedger (single source of truth)
                         ↓
                  Stock Report / Views
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Login |
| GET | `/api/materials` | List materials |
| POST | `/api/materials` | Save material |
| GET | `/api/locations` | List locations |
| POST | `/api/locations` | Save location |
| GET | `/api/opening-stock` | List opening stock |
| POST | `/api/opening-stock` | Save opening stock |
| POST | `/api/purchase-inward` | Stock IN |
| POST | `/api/sales` | Stock OUT |
| GET | `/api/stock-report` | Current stock |
| GET | `/api/stock-ledger` | Transaction ledger |

---

## Tech Stack

- **Frontend:** React 19, Vite, Tailwind CSS, React Router, Axios, Lucide Icons
- **Backend:** Node.js, Express, mssql, JWT, bcryptjs
- **Database:** SQL Server (tables, views, stored procedures)

---

## Production hosting (Amazon EC2)

Full step-by-step guide for **EC2 `13.205.231.60`** + SQL Server **`43.205.62.168`**:

→ **[deploy/DEPLOY-EC2.md](deploy/DEPLOY-EC2.md)**

Includes Nginx, PM2, `.env`, SSL, and security group setup. Config files are in `deploy/`.
