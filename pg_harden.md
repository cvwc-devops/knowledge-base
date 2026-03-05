Part 1: Basic Hardening (The Essentials)
Authorized Repositories
Service Management
Data Checksums
Storage Layout
OS-Level umask
Directory Permissions
Unix Socket Security
PSQL History
Logging Collector
Connection Limits
Part 2: Advanced Protection (Hardening)
pgAudit
LUKS Encryption
SCRAM Authentication
SSL/TLS Enforcement
The set_user Extension
Predefined Roles
Row-Level Security (RLS)
Public Schema Lockdown
Password Complexity
Dynamic Masking
Part 1: Basic Hardening (The Essentials)
1. Authorized Repositories
Ensure you are using the official PostgreSQL Global Development Group (PGDG) repo to avoid tampered binaries.
# Check installed packages (RHEL/CentOS)
rpm -qa | grep postgresql

# Verify PGDG source
rpm -qi postgresql18-server | grep "Signature"
2. Service Management
Enable the database service to ensure it starts correctly after a reboot and verify its status.
# For standard installations
systemctl enable postgresql-18.service
systemctl status postgresql-18.service

# For HA setups (e.g., Patroni)
systemctl status patroni.service
3. Data Checksums
Enable checksums at the cluster level to detect storage-level corruption. This must be done at initialization.
# Check if enabled (Data page checksum version: 1 = Enabled)
sudo -u postgres pg_controldata /pg_data/data/ | grep "Data page checksum version"
4. Storage Layout (Physical Partitioning)
Don’t put everything in one place. Move WAL, Logs, and Temp files to separate physical disks to prevent disk-fill DoS and improve performance.
lsblk
# Example desired mount points:
# /pg_data  -> Database objects
# /pg_wal   -> Write Ahead Logs
# /pg_log   -> Database logs
# /pg_temp  -> Temporary files
5. OS-Level umask
The postgres user’s default umask should be 077 to ensure that new files are not readable by others.
su - postgres
# Check current umask
umask 

# Enforce 077 in .bash_profile
echo 'umask 077' >> ~/.bash_profile
source ~/.bash_profile
6. Directory Permissions
Secure the PGDATA directory. It should be owned by postgres and set to 0700.
# Check permissions
stat -c "%a" /pg_data/data/

# Fix if necessary
chmod 700 /pg_data/data/
7. Unix Socket Security
Unix sockets are more secure than TCP. Restrict who can connect locally.
-- In postgresql.conf
-- 0700: Only the postgres user
-- 0770: Postgres user and dba group
unix_socket_permissions = 0700
8. PSQL History Protection
Prevent leaking sensitive SQL commands or passwords stored in the history file.
# Link history to /dev/null
ln -s /dev/null ~/.psql_history

# Or set via environment variable
sudo echo 'PSQL_HISTORY=/dev/null' >> /etc/environment
9. Logging Collector
Enable the logging collector to capture stderr into rotation-friendly files.
-- Set in postgresql.conf
logging_collector = on
log_directory = '/pg_log/log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0600
10. Connection Limits
Prevent a single user from exhausting all database backends.
-- Check current limits
SELECT rolname, rolconnlimit FROM pg_roles;

-- Set a reasonable limit for non-app users
ALTER USER "developer_account" CONNECTION LIMIT 5;
Part 2: Advanced Protection (Hardening for PostgreSQL 18)
11. pgAudit: Detailed Auditing
Standard logging tells you what the user requested; pgAudit tells you exactly what happened at the object level.
Deep Dive: For a complete walkthrough on setting up audit policies, check out my guide: Postgres Database Audit Policies
-- In postgresql.conf (PostgreSQL 18)
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'ddl, write, role'
12. LUKS Encryption (At-Rest)
Secure the physical layer. If a drive is pulled from the server, the data remains encrypted and inaccessible.
Step-by-Step Guide: Encrypting PostgreSQL Data Directory with LUKS
# PostgreSQL 18 data partition encryption example
cryptsetup luksFormat /dev/nvme0n1p1
cryptsetup open /dev/nvme0n1p1 pg18_encrypted
mount /dev/mapper/pg18_encrypted /var/lib/pgsql/18/data
13. SCRAM-SHA-256 Authentication
PostgreSQL 18 continues to push scram-sha-256 as the gold standard. Avoid broad access; target specific databases and roles.
-- Enforce in postgresql.conf
password_encryption = scram-sha-256

-- Strict pg_hba.conf entry (Targeting specific DB and Group)
# TYPE    DATABASE      USER            ADDRESS         METHOD
hostssl   customer_db   +db_admins      **.**.**.0/24   scram-sha-256
hostssl   sales_prod    +sales_app      **.**.**.50/32  scram-sha-256
14. SSL/TLS Enforcement
In version 18, encrypting traffic is non-negotiable for production. Enforce SSL specifically for administrative roles and groups.
-- Force encrypted connections for the DBA group
# TYPE    DATABASE      USER            ADDRESS         METHOD
hostssl   all           +dba_team       **.**.**.15/30  scram-sha-256
15. The set_user Extension
Avoid permanent superuser sessions. Use this extension to switch to high-privilege roles only when necessary, maintaining a clean audit trail.
-- Switch to superuser role with logging
SELECT set_user('postgres_admin');
-- Perform maintenance
SELECT reset_user();
16. Predefined Roles (New in PG 18)
PostgreSQL 18 expands predefined roles. Use them to follow the “Principle of Least Privilege” instead of granting full superuser status.
-- Grant specific rights without full superuser
GRANT pg_read_all_stats TO "monitoring_user";
GRANT pg_checkpoint TO "backup_admin";
17. Row-Level Security (RLS)
Apply security policies directly to data rows. This ensures users only see records relevant to their authorization level.
Implementation Details: PostgreSQL Row Level Security Guide
ALTER TABLE customer_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY regional_manager_policy ON customer_orders
    USING (region = current_setting('app.current_region'));
18. Public Schema Lockdown
The “Search Path” attack surface is minimized by default in newer versions, but manual hardening is still a critical best practice.
-- Final lockdown for PG 18
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE customer_db FROM PUBLIC;
19. Password Complexity
Use the passwordcheck module to prevent users from setting easily guessable passwords.
-- In postgresql.conf
shared_preload_libraries = 'pgaudit, passwordcheck'
20. Dynamic Data Masking (Anonymizer)
For GDPR/KVKK compliance, mask sensitive data in real-time for non-privileged roles like developers or analysts.
Advanced Masking Techniques: Data Masking in PostgreSQL
-- Masking email addresses for the 'marketing_analyst' role
SECURITY LABEL FOR anon ON ROLE marketing_analyst IS 'MASKED';
SECURITY LABEL FOR anon ON COLUMN users.email
IS 'MASKED WITH FUNCTION anon.partial(email,1,$$***$$,2)';
