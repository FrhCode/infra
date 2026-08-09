# Shared Infra

Repository ini berisi Docker Compose untuk shared infrastructure, termasuk PostgreSQL, Redis, Langfuse, RustFS, dan Firecrawl.

> Penting: PostgreSQL harus dijalankan dan database/user Langfuse harus dibuat terlebih dahulu sebelum Langfuse dinaikkan. Kalau tidak, Langfuse bisa gagal start karena database, user, atau permission belum siap.

## 1. Siapkan environment file

Copy contoh environment file ke `.env`:

```bash
cp ".env example" .env
```

Lalu isi value rahasia di `.env`, minimal:

```env
POSTGRES_USER=infra_admin
POSTGRES_PASSWORD=CHANGE_ME
POSTGRES_DB=postgres

LANGFUSE_DATABASE_URL=postgresql://langfuse_user:CHANGE_ME@postgres:5432/langfuse_prod
```

Pastikan password `langfuse_user` yang nanti dibuat di PostgreSQL sama dengan password di `LANGFUSE_DATABASE_URL`.

## 2. Buat Docker network shared infra

Compose menggunakan external network bernama `shared-infra`, jadi network ini harus dibuat manual sekali saja.

Cek apakah network sudah ada:

```bash
docker network ls | grep shared-infra
```

Kalau belum ada, buat network:

```bash
docker network create shared-infra
```

Kalau command di atas menghasilkan pesan bahwa network sudah ada, berarti aman untuk lanjut.

## 3. Jalankan PostgreSQL saja dulu

Naikkan service PostgreSQL saja:

```bash
docker compose up -d postgres
```

Cek status container:

```bash
docker compose ps postgres
```

Cek logs kalau perlu:

```bash
docker compose logs -f postgres
```

Tunggu sampai PostgreSQL healthy sebelum lanjut ke tahap berikutnya.

## 4. Buat database dan user untuk Langfuse

Masuk ke PostgreSQL menggunakan admin user dari `.env`:

```bash
docker exec -it shared_postgres psql -U infra_admin -d postgres
```

> Kalau `POSTGRES_USER` di `.env` diganti dari `infra_admin`, sesuaikan command di atas.

Jalankan SQL berikut. Ganti `CHANGE_ME_LANGFUSE_PASSWORD` dengan password yang sama seperti di `LANGFUSE_DATABASE_URL`.

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_catalog.pg_roles WHERE rolname = 'langfuse_user'
  ) THEN
    CREATE ROLE langfuse_user LOGIN PASSWORD 'CHANGE_ME_LANGFUSE_PASSWORD';
  ELSE
    ALTER ROLE langfuse_user WITH LOGIN PASSWORD 'CHANGE_ME_LANGFUSE_PASSWORD';
  END IF;
END
$$;
```

Keluar dulu dari `psql`:

```sql
\q
```

Buat database `langfuse_prod` dengan owner `langfuse_user`:

```bash
docker exec -it shared_postgres createdb -U infra_admin -O langfuse_user langfuse_prod
```

Kalau database sudah pernah dibuat dan command di atas error `already exists`, lanjutkan dengan grant permission di bawah.

Masuk ke database Langfuse:

```bash
docker exec -it shared_postgres psql -U infra_admin -d langfuse_prod
```

Lalu jalankan grant berikut:

```sql
GRANT ALL PRIVILEGES ON DATABASE langfuse_prod TO langfuse_user;
GRANT ALL ON SCHEMA public TO langfuse_user;
ALTER SCHEMA public OWNER TO langfuse_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO langfuse_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON SEQUENCES TO langfuse_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON FUNCTIONS TO langfuse_user;
```

Keluar dari `psql`:

```sql
\q
```

## 5. Test koneksi sebagai user Langfuse

Sebelum menjalankan Langfuse, pastikan user Langfuse bisa login ke database:

```bash
docker exec -it shared_postgres psql -U langfuse_user -d langfuse_prod
```

Kalau berhasil masuk ke prompt `psql`, berarti credential dan database sudah siap.

Keluar dari `psql`:

```sql
\q
```

## 6. Jalankan Langfuse setelah database siap

Setelah PostgreSQL, database, user, dan permission siap, baru jalankan Langfuse:

```bash
docker compose up -d langfuse
```

Atau jalankan core services:

```bash
docker compose up -d postgres redis langfuse
```

Cek logs Langfuse:

```bash
docker compose logs -f langfuse
```

## Troubleshooting

### `network shared-infra declared as external, but could not be found`

Buat network terlebih dahulu:

```bash
docker network create shared-infra
```

### `password authentication failed for user "langfuse_user"`

Pastikan password yang dibuat di PostgreSQL sama dengan password di:

```env
LANGFUSE_DATABASE_URL=postgresql://langfuse_user:CHANGE_ME@postgres:5432/langfuse_prod
```

Kalau perlu, update password user:

```bash
docker exec -it shared_postgres psql -U infra_admin -d postgres
```

```sql
ALTER ROLE langfuse_user WITH PASSWORD 'PASSWORD_YANG_BENAR';
```

### `database "langfuse_prod" does not exist`

Buat database terlebih dahulu:

```bash
docker exec -it shared_postgres createdb -U infra_admin -O langfuse_user langfuse_prod
```

### `permission denied for schema public`

Masuk ke database Langfuse:

```bash
docker exec -it shared_postgres psql -U infra_admin -d langfuse_prod
```

Lalu jalankan ulang grant schema:

```sql
GRANT ALL ON SCHEMA public TO langfuse_user;
ALTER SCHEMA public OWNER TO langfuse_user;
```

## Notes

- Jangan menjalankan Langfuse sebelum database `langfuse_prod` dan user `langfuse_user` siap.
- `LANGFUSE_DATABASE_URL` menggunakan host `postgres` karena Langfuse dan PostgreSQL berada di Docker network yang sama.
- External network `shared-infra` dibuat manual supaya bisa dipakai bersama oleh service/repository lain.
- Jangan commit `.env` asli yang berisi password/secrets.
