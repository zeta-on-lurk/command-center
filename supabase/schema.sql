-- ============================================================
-- PROJECT A.D.A.M. — Supabase MVP Schema
-- 12 tables + RLS policies + seed data
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- 1. COLLEGES (Tenants)
-- ============================================================
create table colleges (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    emis_code text unique,
    principal_name text,
    phone text,
    email text,
    address text,
    city text,
    province text,
    board_id uuid,
    college_type text check (college_type in ('boys', 'girls', 'co-ed')),
    subscription_tier text default 'free' check (subscription_tier in ('free', 'basic', 'premium')),
    subscription_expires date,
    settings jsonb default '{}',
    is_active boolean default true,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================================
-- 2. DEPARTMENTS
-- ============================================================
create table departments (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    name text not null,
    code text,
    head_faculty_id uuid,
    is_active boolean default true,
    created_at timestamptz default now()
);

-- ============================================================
-- 3. SECTIONS
-- ============================================================
create table sections (
    id uuid primary key default uuid_generate_v4(),
    department_id uuid references departments(id) on delete cascade,
    name text not null,
    group_name text,
    room_number text,
    capacity int default 60,
    current_enrollment int default 0,
    is_active boolean default true,
    created_at timestamptz default now()
);

-- ============================================================
-- 4. USERS (Auth profiles)
-- ============================================================
create table users (
    id uuid references auth.users(id) on delete cascade,
    college_id uuid references colleges(id) on delete cascade,
    department_id uuid references departments(id),
    email text not null,
    full_name text not null,
    role text not null check (role in ('super_admin', 'principal', 'vice_principal', 'dept_head', 'faculty', 'data_entry', 'viewer')),
    phone text,
    cnic text,
    qualification text,
    designation text,
    is_active boolean default true,
    last_login timestamptz,
    created_at timestamptz default now(),
    primary key (id)
);

-- ============================================================
-- 5. FACULTY
-- ============================================================
create table faculty (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    department_id uuid references departments(id) on delete cascade,
    user_id uuid references users(id),
    name text not null,
    cnic text,
    phone text,
    email text,
    qualification text,
    designation text check (designation in ('Professor', 'Associate Professor', 'Assistant Professor', 'Lecturer', 'SST', 'CT')),
    specialty text,
    subject text,
    joining_date date,
    bps_grade int,
    compliance_score numeric(5,2) default 100,
    is_active boolean default true,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================================
-- 6. STUDENTS
-- ============================================================
create table students (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    section_id uuid references sections(id) on delete set null,
    name text not null,
    father_name text,
    cnic_b_form text,
    phone text,
    email text,
    date_of_birth date,
    gender text check (gender in ('male', 'female', 'other')),
    address text,
    city text,
    matric_roll_no text,
    matric_marks_obtained numeric(6,2),
    matric_total_marks numeric(6,2) default 1100,
    matric_percentage numeric(5,2),
    matric_board text,
    matric_year int,
    admission_date date default now(),
    admission_number text,
    scholarship boolean default false,
    is_active boolean default true,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================================
-- 7. ATTENDANCE DAILY (Student)
-- ============================================================
create table attendance_daily (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    student_id uuid references students(id) on delete cascade,
    section_id uuid references sections(id) on delete set null,
    date date not null,
    status text check (status in ('present', 'absent', 'late', 'leave')),
    time_in time,
    remarks text,
    marked_by uuid references users(id),
    marked_at timestamptz default now(),
    unique(student_id, date)
);

-- ============================================================
-- 8. FACULTY ATTENDANCE
-- ============================================================
create table faculty_attendance (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    faculty_id uuid references faculty(id) on delete cascade,
    date date not null,
    status text check (status in ('present', 'absent', 'late', 'on_leave')),
    time_in time,
    time_out time,
    remarks text,
    marked_by uuid references users(id),
    marked_at timestamptz default now(),
    unique(faculty_id, date)
);

-- ============================================================
-- 9. LECTURES
-- ============================================================
create table lectures (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    faculty_id uuid references faculty(id) on delete cascade,
    section_id uuid references sections(id) on delete set null,
    subject text,
    date date not null,
    period_number int,
    topic_covered text,
    status text check (status in ('delivered', 'cancelled', 'substituted')),
    marked_at timestamptz default now()
);

-- ============================================================
-- 10. SYLLABUS PROGRESS
-- ============================================================
create table syllabus_progress (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    section_id uuid references sections(id) on delete cascade,
    subject text,
    chapter_name text,
    chapter_number int,
    total_topics int,
    completed_topics int,
    completion_pct numeric(5,2) default 0,
    target_date date,
    actual_date date,
    faculty_id uuid references faculty(id),
    updated_at timestamptz default now()
);

-- ============================================================
-- 11. AUDIT LOG
-- ============================================================
create table audit_log (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    user_id uuid references users(id),
    event_type text not null,
    entity_type text,
    entity_id uuid,
    details jsonb,
    ip_address text,
    created_at timestamptz default now()
);

-- ============================================================
-- 12. NOTIFICATION ALERTS
-- ============================================================
create table notification_alerts (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references colleges(id) on delete cascade,
    user_id uuid references users(id),
    type text check (type in ('critical', 'warning', 'info')),
    title text not null,
    message text,
    is_read boolean default false,
    read_at timestamptz,
    created_at timestamptz default now()
);

-- ============================================================
-- INDEXES
-- ============================================================
create index idx_college_id on attendance_daily(college_id);
create index idx_attendance_date on attendance_daily(date);
create index idx_attendance_section on attendance_daily(section_id, date);
create index idx_faculty_attendance_date on faculty_attendance(date);
create index idx_lectures_date on lectures(date);
create index idx_syllabus_section on syllabus_progress(section_id);
create index idx_students_section on students(section_id);
create index idx_users_college on users(college_id);
create index idx_faculty_college on faculty(college_id);
create index idx_notifications_unread on notification_alerts(college_id, is_read) where is_read = false;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table colleges enable row level security;
alter table departments enable row level security;
alter table sections enable row level security;
alter table users enable row level security;
alter table faculty enable row level security;
alter table students enable row level security;
alter table attendance_daily enable row level security;
alter table faculty_attendance enable row level security;
alter table lectures enable row level security;
alter table syllabus_progress enable row level security;
alter table audit_log enable row level security;
alter table notification_alerts enable row level security;

-- Helper function to get user's college_id
create or replace function get_user_college_id()
returns uuid as $$
    select college_id from users where id = auth.uid() and is_active = true;
$$ language sql security definer;

-- Helper function to get user's role
create or replace function get_user_role()
returns text as $$
    select role from users where id = auth.uid() and is_active = true;
$$ language sql security definer;

-- Helper function to get user's department_id
create or replace function get_user_department_id()
returns uuid as $$
    select department_id from users where id = auth.uid() and is_active = true;
$$ language sql security definer;

-- Super admin bypass
create policy "super_admin_all" on colleges
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on departments
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on sections
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on users
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on faculty
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on students
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on attendance_daily
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on faculty_attendance
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on lectures
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on syllabus_progress
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on audit_log
    for all using (get_user_role() = 'super_admin');
create policy "super_admin_all" on notification_alerts
    for all using (get_user_role() = 'super_admin');

-- College-level access (principal, VP, dept_head, faculty, data_entry, viewer)
create policy "college_read" on colleges
    for select using (id = get_user_college_id());
create policy "college_read" on departments
    for select using (college_id = get_user_college_id());
create policy "college_read" on sections
    for select using (
        exists (select 1 from departments d where d.id = sections.department_id and d.college_id = get_user_college_id())
    );
create policy "college_read" on users
    for select using (college_id = get_user_college_id());
create policy "college_read" on faculty
    for select using (college_id = get_user_college_id());
create policy "college_read" on students
    for select using (college_id = get_user_college_id());
create policy "college_read" on attendance_daily
    for select using (college_id = get_user_college_id());
create policy "college_read" on faculty_attendance
    for select using (college_id = get_user_college_id());
create policy "college_read" on lectures
    for select using (college_id = get_user_college_id());
create policy "college_read" on syllabus_progress
    for select using (college_id = get_user_college_id());
create policy "college_read" on audit_log
    for select using (college_id = get_user_college_id());
create policy "college_read" on notification_alerts
    for select using (college_id = get_user_college_id() or user_id = auth.uid());

-- Write access: principal + VP
create policy "college_write" on departments
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal')
    );
create policy "college_write" on sections
    for all using (
        exists (select 1 from departments d where d.id = sections.department_id and d.college_id = get_user_college_id())
        and get_user_role() in ('principal', 'vice_principal')
    );
create policy "college_write" on users
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal')
    );
create policy "college_write" on faculty
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal')
    );
create policy "college_write" on students
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal')
    );
create policy "college_write" on attendance_daily
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head', 'data_entry')
    );
create policy "college_write" on faculty_attendance
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head')
    );
create policy "college_write" on lectures
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head', 'faculty')
    );
create policy "college_write" on syllabus_progress
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal', 'dept_head', 'faculty')
    );
create policy "college_write" on notification_alerts
    for all using (
        college_id = get_user_college_id() and get_user_role() in ('principal', 'vice_principal')
    );

-- Department head: write only their department
create policy "dept_head_write" on faculty
    for all using (
        department_id = get_user_department_id() and get_user_role() = 'dept_head'
    );
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
    for all using (faculty_id = auth.uid() and get_user_role() = 'faculty');
create policy "faculty_write_own" on syllabus_progress
    for all using (faculty_id = auth.uid() and get_user_role() = 'faculty');
create policy "faculty_write_own" on faculty_attendance
    for select using (faculty_id = auth.uid() and get_user_role() = 'faculty');

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger trg_colleges_updated before update on colleges for each row execute function update_updated_at();
create trigger trg_faculty_updated before update on faculty for each row execute function update_updated_at();
create trigger trg_students_updated before update on students for each row execute function update_updated_at();
create trigger trg_syllabus_updated before update on syllabus_progress for each row execute function update_updated_at();

-- Auto-calculate matric percentage
create or replace function calc_matric_percentage()
returns trigger as $$
begin
    if new.matric_marks_obtained is not null and new.matric_total_marks > 0 then
        new.matric_percentage = round((new.matric_marks_obtained / new.matric_total_marks) * 100, 2);
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_calc_percentage before insert or update on students for each row execute function calc_matric_percentage();

-- Auto-calculate syllabus completion pct
create or replace function calc_syllabus_pct()
returns trigger as $$
begin
    if new.total_topics > 0 then
        new.completion_pct = round((new.completed_topics::numeric / new.total_topics) * 100, 2);
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_calc_syllabus_pct before insert or update on syllabus_progress for each row execute function calc_syllabus_pct();

-- ============================================================
-- SEED DATA (Demo College)
-- ============================================================

-- Note: In production, users are created via Supabase Auth signup.
-- These seed entries assume you'll create the auth user first, then insert the profile.

-- Insert demo college
insert into colleges (id, name, emis_code, principal_name, phone, email, address, city, province, college_type, settings)
values (
    'a0000000-0000-0000-0000-000000000001',
    'Govt. College — Main Campus',
    '352101-0042',
    'Dr. Muhammad Ashraf',
    '+92 42 1234567',
    'principal@govtcollege.edu.pk',
    'Mall Road, Lahore, Punjab, Pakistan',
    'Lahore',
    'Punjab',
    'boys',
    '{"lectures_per_day": 6, "lecture_duration": 45, "start_time": "08:00", "end_time": "14:00", "board": "FBISE"}'::jsonb
) on conflict (id) do nothing;

-- Insert departments
insert into departments (id, college_id, name, code) values
    ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Pre-Medical', 'PM'),
    ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Pre-Engineering', 'PE'),
    ('d0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'ICS', 'ICS'),
    ('d0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'ICom', 'IC'),
    ('d0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'FA', 'FA')
on conflict (id) do nothing;

-- Insert sections
insert into sections (id, department_id, name, group_name, room_number, capacity) values
    ('50000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Section A', 'Pre-Medical A', 'Room 101', 60),
    ('50000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001', 'Section B', 'Pre-Medical B', 'Room 102', 60),
    ('50000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000002', 'Section A', 'Pre-Engineering A', 'Room 201', 60),
    ('50000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000002', 'Section B', 'Pre-Engineering B', 'Room 202', 60),
    ('50000000-0000-0000-0000-000000000005', 'd0000000-0000-0000-0000-000000000003', 'Section A', 'ICS A (Physics-Maths-CS)', 'Room 301', 60),
    ('50000000-0000-0000-0000-000000000006', 'd0000000-0000-0000-0000-000000000004', 'Section A', 'ICom A', 'Room 401', 60),
    ('50000000-0000-0000-0000-000000000007', 'd0000000-0000-0000-0000-000000000005', 'Section A', 'FA Group I', 'Room 501', 60)
on conflict (id) do nothing;

-- Insert faculty
insert into faculty (id, college_id, department_id, name, phone, email, qualification, designation, specialty, subject, compliance_score) values
    ('f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Prof. Naveed Ahmed', '+92 300 1234567', 'naveed.ahmed@govtcollege.edu.pk', 'M.Phil Physics', 'Professor', 'FBISE Prep', 'Physics', 96.2),
    ('f0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Dr. Saima Rashid', '+92 301 2345678', 'saima.rashid@govtcollege.edu.pk', 'PhD Chemistry', 'Associate Professor', 'Organic Unit', 'Chemistry', 94.8),
    ('f0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'Mr. Tariq Mehmood', '+92 302 3456789', 'tariq.m@govtcollege.edu.pk', 'MSc Mathematics', 'Lecturer', 'Calculus', 'Mathematics', 61.4),
    ('f0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Ms. Fatima Zahra', '+92 303 4567890', 'fatima.z@govtcollege.edu.pk', 'MSc Biology', 'Lecturer', 'Human Physiology', 'Biology', 91.5),
    ('f0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Mr. Usman Khalid', '+92 304 5678901', 'usman.k@govtcollege.edu.pk', 'MA English', 'Lecturer', 'Grammar & Composition', 'English', 78.3),
    ('f0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000003', 'Prof. Asad Ullah', '+92 305 6789012', 'asad.ullah@govtcollege.edu.pk', 'MCS', 'Professor', 'Programming', 'Computer Science', 93.7),
    ('f0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'Mr. Faisal Rehman', '+92 306 7890123', 'faisal.r@govtcollege.edu.pk', 'MSc Physics', 'Lecturer', 'Mechanics Unit', 'Physics', 74.1),
    ('f0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Dr. Ayesha Siddiqui', '+92 307 8901234', 'ayesha.s@govtcollege.edu.pk', 'PhD Chemistry', 'Associate Professor', 'Inorganic Unit', 'Chemistry', 97.1),
    ('f0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000005', 'Mr. Junaid Akram', '+92 308 9012345', 'junaid.a@govtcollege.edu.pk', 'MA Urdu', 'Lecturer', 'Literature', 'Urdu', 88.5)
on conflict (id) do nothing;

-- Insert demo students
insert into students (id, college_id, section_id, name, father_name, gender, city, matric_percentage, matric_year) values
    ('57000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Abdullah Khan', 'Khalid Khan', 'male', 'Lahore', 85.5, 2024),
    ('57000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Ayesha Malik', 'Tariq Malik', 'female', 'Lahore', 92.1, 2024),
    ('57000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'Bilal Hussain', 'Imran Hussain', 'male', 'Lahore', 78.3, 2024),
    ('57000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Daniyal Ahmed', 'Shahid Ahmed', 'male', 'Lahore', 88.7, 2024),
    ('57000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000005', 'Fatima Noor', 'Asad Noor', 'female', 'Lahore', 90.2, 2024),
    ('57000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'Hamza Tariq', 'Mehmood Tariq', 'male', 'Lahore', 72.4, 2024),
    ('57000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'Ibrahim Shah', 'Rashid Shah', 'male', 'Lahore', 81.6, 2024),
    ('57000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000007', 'Khadija Begum', 'Nasir Beg', 'female', 'Lahore', 76.8, 2024),
    ('57000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Muzammil Ali', 'Farooq Ali', 'male', 'Lahore', 83.9, 2024),
    ('57000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000005', 'Nadia Parveen', 'Kamran Parveen', 'female', 'Lahore', 87.3, 2024),
    ('57000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'Omar Farooq', 'Yousaf Farooq', 'male', 'Lahore', 79.5, 2024),
    ('57000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000007', 'Zainab Noor', 'Tariq Noor', 'female', 'Lahore', 74.2, 2024)
on conflict (id) do nothing;

-- Insert demo attendance (today)
insert into attendance_daily (college_id, student_id, section_id, date, status, time_in, remarks) values
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', current_date, 'present', '07:45', null),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', current_date, 'present', '07:50', null),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000003', current_date, 'absent', null, '5th consecutive absence'),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000001', current_date, 'late', '08:15', 'Late by 15 minutes'),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000005', current_date, 'present', '07:40', null),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000003', current_date, 'absent', null, '2nd consecutive absence'),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000007', '50000000-0000-0000-0000-000000000003', current_date, 'present', '07:55', null),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000008', '50000000-0000-0000-0000-000000000007', current_date, 'present', '07:48', null),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000009', '50000000-0000-0000-0000-000000000001', current_date, 'absent', null, 'Medical leave'),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000010', '50000000-0000-0000-0000-000000000005', current_date, 'late', '08:20', 'Late by 20 minutes'),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000011', '50000000-0000-0000-0000-000000000003', current_date, 'present', '07:42', null),
    ('a0000000-0000-0000-0000-000000000001', '57000000-0000-0000-0000-000000000012', '50000000-0000-0000-0000-000000000007', current_date, 'absent', null, '4th consecutive absence')
on conflict (student_id, date) do nothing;

-- Insert demo faculty attendance
insert into faculty_attendance (college_id, faculty_id, date, status, time_in, time_out) values
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', current_date, 'present', '07:30', '14:00'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', current_date, 'present', '07:35', '14:00'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', current_date, 'absent', null, null),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000004', current_date, 'present', '07:40', '14:00'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000005', current_date, 'late', '08:10', '14:00'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000006', current_date, 'present', '07:25', '14:00'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', current_date, 'present', '07:50', '14:00'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', current_date, 'present', '07:30', '14:00'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000009', current_date, 'present', '07:45', '14:00')
on conflict (faculty_id, date) do nothing;

-- Insert demo lectures
insert into lectures (college_id, faculty_id, section_id, subject, date, period_number, topic_covered, status) values
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Physics', current_date, 1, 'Optics — Reflection & Refraction', 'delivered'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'Chemistry', current_date, 2, 'Organic Reactions — Esterification', 'delivered'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000001', 'Biology', current_date, 3, 'Human Heart — Cardiac Cycle', 'delivered'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000005', 'Computer Science', current_date, 1, 'C++ — Pointers & Memory', 'delivered'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', '50000000-0000-0000-0000-000000000003', 'Physics', current_date, 2, 'Mechanics — Newton Laws', 'delivered'),
    ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', '50000000-0000-0000-0000-000000000002', 'Chemistry', current_date, 3, 'Periodic Table — Trends', 'delivered')
on conflict do nothing;

-- Insert demo syllabus progress
insert into syllabus_progress (college_id, section_id, subject, chapter_name, chapter_number, total_topics, completed_topics, target_date, faculty_id) values
    ('a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Physics', 'Optics', 8, 12, 11, '2026-04-15', 'f0000000-0000-0000-0000-000000000001'),
    ('a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Chemistry', 'Organic Chemistry', 14, 15, 14, '2026-04-20', 'f0000000-0000-0000-0000-000000000002'),
    ('a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Biology', 'Human Physiology', 10, 14, 12, '2026-04-18', 'f0000000-0000-0000-0000-000000000004'),
    ('a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'Mathematics', 'Calculus', 6, 10, 7, '2026-04-10', 'f0000000-0000-0000-0000-000000000003'),
    ('a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000005', 'Computer Science', 'Programming in C++', 5, 8, 7, '2026-04-12', 'f0000000-0000-0000-0000-000000000006'),
    ('a0000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'Physics', 'Mechanics', 4, 10, 6, '2026-04-08', 'f0000000-0000-0000-0000-000000000007')
on conflict do nothing;

-- Insert demo notifications
insert into notification_alerts (college_id, type, title, message) values
    ('a0000000-0000-0000-0000-000000000001', 'critical', 'Faculty Absent — 3 Consecutive Days', 'Mr. Tariq Mehmood has been absent for 3 consecutive days without leave application.'),
    ('a0000000-0000-0000-0000-000000000001', 'critical', 'Unmarked Lectures — Pre-Engineering', '4 lectures remain unmarked in Pre-Engineering section for this week.'),
    ('a0000000-0000-0000-0000-000000000001', 'warning', 'Syllabus Behind Schedule', 'FSc General Physics syllabus is 12% behind the FBISE schedule.'),
    ('a0000000-0000-0000-0000-000000000001', 'info', 'Friday Compliance Report Ready', 'Weekly compliance report has been generated and is available for download.')
on conflict do nothing;
