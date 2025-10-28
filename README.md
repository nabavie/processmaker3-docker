# Dockerized ProcessMaker 3

This repository provides a fully **Dockerized setup** for **ProcessMaker 3** — the most comprehensive open-source **Business Process Management (BPM)** platform. Enhanced with modern DevOps practices, **advanced security hardening**, **performance optimizations**, and **multi-database support**, this setup is **production-ready** and scalable.

---

## Why ProcessMaker 3?

ProcessMaker 3 remains the **gold standard** for open-source BPM due to its rich, battle-tested feature set:

- **Multi-database support**: Oracle, SQL Server, MySQL, PostgreSQL
- **Flexible authentication**: LDAP, custom methods
- **Easy form & process design** with drag-and-drop
- **Huge community plugin ecosystem**
- **Advanced reporting**, dashboards, calendars, roles, mobile support
- **REST API** and external system integration
- **Full workflow automation** with triggers, timers, and notifications

> While **ProcessMaker 4** introduces modern UI and features, its **community edition removes core BPM defaults**, pushing users toward enterprise upgrades. Rebuilding those features takes significant time — this project keeps **ProcessMaker 3 fully functional and optimized**.

---

## Key Features

### **Multi-Stage Dockerfile Build**
- Dependencies (zlib 1.3.1, OpenSSL 1.1.1w) compiled in a **builder stage**
- Only runtime artifacts copied to final image → **smaller size, fewer vulnerabilities**

### **Advanced Security Hardening**
- **Patched CVE-2023-45853** with secure **zlib 1.3.1**
- **XSS & SQL Injection filters** in `security-filter.php` + Apache rewrite rules
- **Security headers**:
  - `X-Content-Type-Options: nosniff`
  - `Strict-Transport-Security`
  - `X-Frame-Options: SAMEORIGIN`
  - `Referrer-Policy`, `Permissions-Policy`
- **PHP restrictions**: `open_basedir`, `allow_url_fopen=Off`
- **Secure sessions**: `session.cookie_secure=1`, `session.cookie_samesite=Strict`
- **Rate limiting**, HTTP method restrictions, sensitive file blocking

### **Redis-Powered Session Management**
- **Redis 7.4.1** with optimized config (`maxmemory`, `appendonly yes`)
- Risky commands disabled (`FLUSHDB`, `FLUSHALL`)
- **File-based fallback** if Redis is unavailable
- Tune `maxmemory` in `redis.conf` (e.g., 1GB for medium workloads)

### **Full Database Support & Tuning**
- Drivers: **MySQL, Oracle (oci8), PostgreSQL, SQL Server (sqlsrv/pdo_sqlsrv)**
- **Percona Server 8.0.42** with production-grade tuning in `my.cnf`:
  - `innodb_buffer_pool_size` (e.g., 1536M for 2GB RAM)
  - `innodb_flush_method=O_DIRECT`
  - `skip_name_resolve=1`, `innodb_file_per_table`

### **Performance Optimizations**
- **OPcache enabled** with tuned settings:
  - `opcache.memory_consumption=256`
  - `opcache.max_accelerated_files=30000`
- **Static asset caching & compression** (1-day expires for images/CSS/JS)
- **Nginx + Apache** with `mod_deflate`, `expires`, and proxy tuning
- **Redis & MySQL tuning**: `hz`, `maxclients`, `max_connections`, `thread_cache_size`
- **Cron jobs** for workflow execution, logged to `/opt/processmaker/pm_cron.log`

### **Future Enhancements (In Development)**
- Custom modern frontend interface
- Google Authentication (SSO)

---

## Prerequisites

- **Docker** ≥ 20.10
- **Docker Compose** ≥ 2.0
- OS: Linux (recommended), macOS, or Windows with WSL2
- Minimum resources: **2GB RAM**, **4GB disk**

---

## Installation & Setup

```bash
# 1. Clone the repository
git clone https://github.com/nabavie/processmaker3-docker.git
cd processmaker3-docker

# 2. Build images (multi-stage)
docker compose build

# 3. Start containers in background
docker compose up -d

# 4. Follow logs in real-time
docker compose logs -f
