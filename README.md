# Dockerized ProcessMaker 3

This repository contains a Dockerized setup for **ProcessMaker 3**, a powerful open-source Business Process Management (BPM) platform. This project enhances ProcessMaker 3 with modern DevOps practices, robust security, and performance optimizations, making it production-ready for scalable deployments.

## Key Features

- **Multi-Stage Dockerfile Build**:
  - Utilizes a multi-stage build process to optimize image size and security.
  - Compiles dependencies (e.g., zlib 1.3.1, OpenSSL 1.1.1w) in a builder stage and copies only necessary artifacts to the final image, reducing vulnerabilities and image bloat.

- **Security Hardening**:
  - Patched critical vulnerabilities, including zlib 1.3.1 to address **CVE-2023-45853**.
  - Implemented XSS and SQL injection filters in `security-filter.php` and Apache’s `000-default.conf` with rewrite rules to block malicious requests.
  - Configured security headers (`X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `X-Frame-Options: SAMEORIGIN`) in `nginx.conf` and `000-default.conf`.
  - Restricted file access with `open_basedir`, disabled `allow_url_fopen`, and enforced `session.cookie_secure` and `session.cookie_samesite=Strict` in `php.ini`.

- **Redis for Session Management**:
  - Integrated **Redis 7.4.1** with optimized settings (e.g., `maxmemory`, `appendonly yes`, disabled `FLUSHDB/FLUSHALL`) for reliable and high-performance session handling. Adjust `maxmemory` in `redis.conf` based on your system resources (e.g., 1GB for medium workloads).
  - Fallback to file-based sessions if Redis is unavailable.

- **Database Support and Tuning**:
  - Added drivers for **MySQL**, **Oracle (oci8)**, **PostgreSQL (pgsql, pdo_pgsql)**, and **SQL Server (sqlsrv, pdo_sqlsrv)** for flexible database integration.
  - Optimized **Percona Server 8.0.42** with settings in `my.cnf`:
    - `innodb_buffer_pool_size`: Set based on available RAM (e.g., 1536M for 2GB systems).
    - `innodb_flush_method=O_DIRECT`
    - `skip_name_resolve=1`
  - Adjust database settings in `my.cnf` to match your hardware and workload.

- **Performance Optimizations**:
  - Enabled **OPcache** in `php.ini` with settings like `opcache.memory_consumption` and `opcache.max_accelerated_files` for faster PHP execution. Configure these based on your application needs (e.g., `opcache.memory_consumption=256`).
  - Configured **Nginx** and **Apache** with caching for static assets (`expires 1d` for images, CSS, JS) and compression (`mod_deflate`) to reduce latency.
  - Tuned Redis (e.g., `hz`, `maxclients`) and MySQL (e.g., `max_connections`, `thread_cache_size`) for high throughput. Adjust these in `redis.conf` and `my.cnf` based on your system capacity.

- **Additional Contributions (Not in This Repo)**:
  - Developed a custom frontend interface to enhance user experience, planned for future integration.
  - Implemented Google Authentication for secure single sign-on (SSO), to be added in upcoming releases.

## Why ProcessMaker 3?

ProcessMaker 3 is a robust open-source BPM platform, offering full workflow automation capabilities. While ProcessMaker 4 introduces advanced features, its community edition lacks some core functionalities to push users toward the enterprise version. This Dockerized ProcessMaker 3 setup provides a complete, secure, and optimized solution for open-source enthusiasts.

## Prerequisites

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- A compatible operating system (Linux, macOS, or Windows with WSL2 recommended)

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/nabavie/processmaker3-docker.git
   cd processmaker3-docker