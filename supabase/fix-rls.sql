-- ============================================================
-- FIX: Drop broken RLS policies and recreate correctly
-- Run this ONCE in SQL Editor to fix all RLS issues
-- ============================================================

-- Drop existing broken policies on users
drop policy if exists "college_read" on users;
drop policy if exists "college_write" on users;

-- Drop existing broken policies on other tables (recreate below)
drop policy if exists "sa_all_colleges" on colleges;
drop policy if exists "sa_all_departments" on departments;
drop policy if exists "sa_all_sections" on sections;
drop policy if exists "sa_all_users" on users;
drop policy if exists "sa_all_faculty" on faculty;
drop policy if exists "sa_all_students" on students;
drop policy if exists "sa_all_attendance" on attendance_daily;
drop policy if exists "sa_all_faculty_att" on faculty_attendance;
drop policy if exists "sa_all_lectures" on lectures;
drop policy if exists "sa_all_syllabus" on syllabus_progress;
drop policy if exists "sa_all_audit" on audit_log;
drop policy if exists "sa_all_notifications" on notification_alerts;

drop policy if exists "college_read" on colleges;
drop policy if exists "college_read" on departments;
drop policy if exists "college_read" on sections;
drop policy if exists "college_read" on faculty;
drop policy if exists "college_read" on students;
drop policy if exists "college_read" on attendance_daily;
drop policy if exists "college_read" on faculty_attendance;
drop policy if exists "college_read" on lectures;
drop policy if exists "college_read" on syllabus_progress;
drop policy if exists "college_read" on audit_log;
drop policy if exists "college_read" on notification_alerts;

drop policy if exists "college_write" on departments;
drop policy if exists "college_write" on sections;
drop policy if exists "college_write" on faculty;
drop policy if exists "college_write" on students;
drop policy if exists "college_write" on attendance_daily;
drop policy if exists "college_write" on faculty_attendance;
drop policy if exists "college_write" on lectures;
drop policy if exists "college_write" on syllabus_progress;
drop policy if exists "college_write" on notification_alerts;

drop policy if exists "dept_head_write" on faculty;
drop policy if exists "dept_head_write" on students;
drop policy if exists "dept_head_write" on attendance_daily;
drop policy if exists "dept_head_write" on lectures;
drop policy if exists "dept_head_write" on syllabus_progress;

drop policy if exists "faculty_write_own" on lectures;
drop policy if exists "faculty_write_own" on syllabus_progress;
drop policy if exists "faculty_read_own_att" on faculty_attendance;
drop policy if exists "audit_read" on audit_log;

-- ============================================================
-- HELPER: Get user college_id directly from auth.uid()
-- This avoids the circular dependency
-- ============================================================
create or replace function get_user_college_id()
returns uuid as $$
    select college_id from users where id = auth.uid() and is_active = true;
$$ language sql security definer;

create or replace function get_user_role()
returns text as $$
    select role from users where id = auth.uid() and is_active = true;
$$ language sql security definer;

create or replace function get_user_department_id()
returns uuid as $$
    select department_id from users where id = auth.uid() and is_active = true;
$$ language sql security definer;

-- ============================================================
-- USERS TABLE — Fixed RLS (no circular dependency)
-- ============================================================

-- 1. Any authenticated user can read their OWN row (breaks circular dep)
create policy "users_read_own" on users
    for select using (id = auth.uid());

-- 2. Super admin: full access
create policy "users_sa_all" on users
    for all using (
        exists (select 1 from users u where u.id = auth.uid() and u.role = 'super_admin' and u.is_active = true)
    );

-- 3. Principal/VP: read all users in their college
create policy "users_college_read" on users
    for select using (
        college_id = (select college_id from users where id = auth.uid() and is_active = true)
        and exists (select 1 from users u where u.id = auth.uid() and u.role in ('principal', 'vice_principal', 'dept_head') and u.is_active = true)
    );

-- 4. Principal/VP: write all users in their college
create policy "users_college_write" on users
    for all using (
        college_id = (select college_id from users where id = auth.uid() and is_active = true)
        and exists (select 1 from users u where u.id = auth.uid() and u.role in ('principal', 'vice_principal') and u.is_active = true)
    );

-- ============================================================
-- SUPER ADMIN — All tables
-- ============================================================
create policy "sa_all" on colleges for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on departments for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on sections for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on faculty for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on students for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on attendance_daily for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on faculty_attendance for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on lectures for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on syllabus_progress for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on audit_log for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));
create policy "sa_all" on notification_alerts for all using (exists (select 1 from users where id = auth.uid() and role = 'super_admin' and is_active = true));

-- ============================================================
-- COLLEGE-LEVEL READ — All authenticated users
-- ============================================================
create policy "read_college" on colleges
    for select using (id = get_user_college_id());

create policy "read_college" on departments
    for select using (college_id = get_user_college_id());

create policy "read_college" on sections
    for select using (
        exists (select 1 from departments d where d.id = sections.department_id and d.college_id = get_user_college_id())
    );

create policy "read_college" on faculty
    for select using (college_id = get_user_college_id());

create policy "read_college" on students
    for select using (college_id = get_user_college_id());

create policy "read_college" on attendance_daily
    for select using (college_id = get_user_college_id());

create policy "read_college" on faculty_attendance
    for select using (college_id = get_user_college_id());

create policy "read_college" on lectures
    for select using (college_id = get_user_college_id());

create policy "read_college" on syllabus_progress
    for select using (college_id = get_user_college_id());

create policy "read_college" on audit_log
    for select using (college_id = get_user_college_id());

create policy "read_college" on notification_alerts
    for select using (college_id = get_user_college_id() or user_id = auth.uid());

-- ============================================================
-- WRITE ACCESS — By role
-- ============================================================

-- Principal + VP: write everything in their college
create policy "write_college" on departments
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal'));

create policy "write_college" on sections
    for all using (
        exists (select 1 from departments d where d.id = sections.department_id and d.college_id = get_user_college_id())
        and get_user_role() in ('principal', 'vice_principal')
    );

create policy "write_college" on faculty
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal'));

create policy "write_college" on students
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal'));

create policy "write_college" on attendance_daily
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head', 'data_entry'));

create policy "write_college" on faculty_attendance
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head'));

create policy "write_college" on lectures
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head', 'faculty'));

create policy "write_college" on syllabus_progress
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head', 'faculty'));

create policy "write_college" on notification_alerts
    for all using (college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal'));

-- Department head: write only their department
create policy "dept_head_write" on faculty
    for all using (department_id = get_user_department_id() and get_user_role() = 'dept_head');

create policy "dept_head_write" on students
    for all using (
        exists (select 1 from sections s join departments d on s.department_id = d.id where s.id = students.section_id and d.id = get_user_department_id())
        and get_user_role() = 'dept_head'
    );

create policy "dept_head_write" on attendance_daily
    for all using (
        exists (select 1 from sections s join departments d on s.department_id = d.id where s.id = attendance_daily.section_id and d.id = get_user_department_id())
        and get_user_role() = 'dept_head'
    );

create policy "dept_head_write" on lectures
    for all using (
        exists (select 1 from sections s join departments d on s.department_id = d.id where s.id = lectures.section_id and d.id = get_user_department_id())
        and get_user_role() = 'dept_head'
    );

create policy "dept_head_write" on syllabus_progress
    for all using (
        exists (select 1 from sections s join departments d on s.department_id = d.id where s.id = syllabus_progress.section_id and d.id = get_user_department_id())
        and get_user_role() = 'dept_head'
    );

-- Faculty: write own data only
create policy "faculty_write_own" on lectures
    for all using (faculty_id = (select id from faculty where user_id = auth.uid()) and get_user_role() = 'faculty');

create policy "faculty_write_own" on syllabus_progress
    for all using (faculty_id = (select id from faculty where user_id = auth.uid()) and get_user_role() = 'faculty');

create policy "faculty_read_own_att" on faculty_attendance
    for select using (faculty_id = (select id from faculty where user_id = auth.uid()) and get_user_role() = 'faculty');

-- Audit log: read-only
create policy "audit_read" on audit_log
    for select using (college_id = get_user_college_id());
