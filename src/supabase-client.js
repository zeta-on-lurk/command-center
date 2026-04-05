// ============================================================
// SUPABASE CLIENT — Command Center SaaS
// ============================================================

var SUPABASE_URL = '';
var SUPABASE_ANON_KEY = '';

var supabaseClient = null;

function initSupabase(url, key) {
    SUPABASE_URL = url;
    SUPABASE_ANON_KEY = key;
    supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

// Auth
async function signIn(email, password) {
    if (!supabaseClient) throw new Error('Supabase not initialized');
    var result = await supabaseClient.auth.signInWithPassword({ email: email, password: password });
    if (result.error) throw result.error;
    return result.data;
}

async function signOut() {
    if (!supabaseClient) return;
    await supabaseClient.auth.signOut();
}

async function getCurrentUser() {
    if (!supabaseClient) return null;
    var result = await supabaseClient.auth.getUser();
    return result.data.user;
}

async function getUserProfile() {
    if (!supabaseClient) return null;
    var user = await getCurrentUser();
    if (!user) return null;
    var result = await supabaseClient.from('users').select('*').eq('id', user.id).single();
    return result.data;
}

// Data queries
async function getDepartments() {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('departments').select('*').eq('is_active', true).order('name');
    return result.data || [];
}

async function getSections() {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('sections').select('*, departments(name)').eq('is_active', true).order('name');
    return result.data || [];
}

async function getFaculty() {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('faculty').select('*').eq('is_active', true).order('name');
    return result.data || [];
}

async function getFacultyByDepartment(deptId) {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('faculty').select('*').eq('department_id', deptId).eq('is_active', true).order('name');
    return result.data || [];
}

async function getStudents() {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('students').select('*, sections(name, departments(name))').eq('is_active', true).order('name');
    return result.data || [];
}

async function getStudentsBySection(sectionId) {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('students').select('*').eq('section_id', sectionId).eq('is_active', true).order('name');
    return result.data || [];
}

async function getAttendanceByDate(date) {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('attendance_daily').select('*, students(name, father_name), sections(name)').eq('date', date).order('students(name)');
    return result.data || [];
}

async function getFacultyAttendanceByDate(date) {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('faculty_attendance').select('*, faculty(name, department_id)').eq('date', date).order('faculty(name)');
    return result.data || [];
}

async function getLecturesByDate(date) {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('lectures').select('*, faculty(name), sections(name)').eq('date', date).order('period_number');
    return result.data || [];
}

async function getSyllabusProgress() {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('syllabus_progress').select('*, sections(name), faculty(name)').order('subject');
    return result.data || [];
}

async function getNotifications() {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('notification_alerts').select('*').order('created_at', { ascending: false }).limit(50);
    return result.data || [];
}

async function getAuditLog() {
    if (!supabaseClient) return [];
    var result = await supabaseClient.from('audit_log').select('*').order('created_at', { ascending: false }).limit(100);
    return result.data || [];
}

async function getCollegeSettings() {
    if (!supabaseClient) return {};
    var result = await supabaseClient.from('colleges').select('settings').limit(1).single();
    return (result.data && result.data.settings) || {};
}

// Data mutations
async function insertAttendance(rows) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('attendance_daily').upsert(rows, { onConflict: 'student_id,date' });
    if (result.error) throw result.error;
    return result.data;
}

async function insertFacultyAttendance(rows) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('faculty_attendance').upsert(rows, { onConflict: 'faculty_id,date' });
    if (result.error) throw result.error;
    return result.data;
}

async function insertLectures(rows) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('lectures').insert(rows);
    if (result.error) throw result.error;
    return result.data;
}

async function insertFaculty(rows) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('faculty').insert(rows);
    if (result.error) throw result.error;
    return result.data;
}

async function updateFaculty(id, data) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('faculty').update(data).eq('id', id);
    if (result.error) throw result.error;
    return result.data;
}

async function deleteFaculty(ids) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('faculty').delete().in('id', ids);
    if (result.error) throw result.error;
    return result.data;
}

async function insertStudents(rows) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('students').insert(rows);
    if (result.error) throw result.error;
    return result.data;
}

async function updateStudent(id, data) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('students').update(data).eq('id', id);
    if (result.error) throw result.error;
    return result.data;
}

async function deleteStudents(ids) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('students').delete().in('id', ids);
    if (result.error) throw result.error;
    return result.data;
}

async function insertSyllabusProgress(rows) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('syllabus_progress').upsert(rows);
    if (result.error) throw result.error;
    return result.data;
}

async function markNotificationRead(id) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from('notification_alerts').update({ is_read: true, read_at: new Date().toISOString() }).eq('id', id);
    if (result.error) throw result.error;
    return result.data;
}

// Bulk CSV import
async function bulkInsert(table, rows) {
    if (!supabaseClient) throw new Error('Not connected');
    var result = await supabaseClient.from(table).insert(rows);
    if (result.error) throw result.error;
    return result.data;
}

// Realtime subscriptions
function subscribeToAttendance(callback) {
    if (!supabaseClient) return null;
    return supabaseClient.channel('attendance_changes')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'attendance_daily' }, function(payload) {
            callback(payload);
        })
        .subscribe();
}

function subscribeToFacultyAttendance(callback) {
    if (!supabaseClient) return null;
    return supabaseClient.channel('faculty_attendance_changes')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'faculty_attendance' }, function(payload) {
            callback(payload);
        })
        .subscribe();
}

function subscribeToNotifications(callback) {
    if (!supabaseClient) return null;
    return supabaseClient.channel('notification_changes')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notification_alerts' }, function(payload) {
            callback(payload.new);
        })
        .subscribe();
}

function unsubscribe(channel) {
    if (channel && supabaseClient) {
        supabaseClient.removeChannel(channel);
    }
}

// Audit logging
async function logAudit(eventType, entityType, entityId, details) {
    if (!supabaseClient) return;
    var user = await getCurrentUser();
    await supabaseClient.from('audit_log').insert({
        college_id: null,
        user_id: user ? user.id : null,
        event_type: eventType,
        entity_type: entityType,
        entity_id: entityId,
        details: details || {},
        ip_address: ''
    });
}
