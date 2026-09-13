-- =============================================================================
-- Migration 013 — Seed initial super_admin account
--
-- This is a one-time bootstrap migration. Without it the admin_users table
-- is empty and the POST /admin/admins endpoint (which requires an existing
-- authenticated admin) can never be called — making first login impossible.
--
-- Password: Admin@1234Dev@@@@1234  (bcrypt, rounds=12)
-- Change the password immediately after first login via the admin panel.
-- =============================================================================

INSERT INTO admin_users (email, password_hash, full_name, role, is_active)
VALUES (
    'admin@vivamatrimony.in',
    '$2b$12$4bmzErLUrblsmOdOj5Gl2eNExsZn8rFHk2lQLzfFs4apnY5sEHdT6',
    'Viva Super Admin',
    'super_admin',
    TRUE
)
ON CONFLICT (email) DO NOTHING;
