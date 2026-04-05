// ============================================================
// SECURITY MODULE — A.D.A.M. SaaS
// XSS prevention, input sanitization, session management,
// audit logging, tamper detection, rate limiting
// ============================================================

var Security = (function() {
    'use strict';

    // ============================================================
    // CONFIGURATION
    // ============================================================
    var CONFIG = {
        sessionTimeout: 30 * 60 * 1000,       // 30 minutes
        inactivityTimeout: 15 * 60 * 1000,     // 15 minutes
        maxLoginAttempts: 5,
        lockoutDuration: 15 * 60 * 1000,       // 15 minutes
        passwordMinLength: 8,
        csrfTokenKey: 'adam_csrf',
        sessionKey: 'adam_session',
        userKey: 'adam_user',
        integrityKey: 'adam_integrity',
        loginAttemptsKey: 'adam_login_attempts',
        allowedOrigins: [window.location.origin]
    };

    // ============================================================
    // XSS PREVENTION
    // ============================================================
    function sanitize(str) {
        if (typeof str !== 'string') return str;
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(str));
        return div.innerHTML;
    }

    function sanitizeObject(obj) {
        if (!obj || typeof obj !== 'object') return obj;
        var clean = {};
        Object.keys(obj).forEach(function(key) {
            if (typeof obj[key] === 'string') {
                clean[key] = sanitize(obj[key]);
            } else if (typeof obj[key] === 'object' && obj[key] !== null) {
                clean[key] = sanitizeObject(obj[key]);
            } else {
                clean[key] = obj[key];
            }
        });
        return clean;
    }

    function sanitizeArray(arr) {
        if (!Array.isArray(arr)) return arr;
        return arr.map(function(item) {
            return typeof item === 'object' ? sanitizeObject(item) : sanitize(item);
        });
    }

    function escapeHtml(str) {
        if (typeof str !== 'string') return str;
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
                  .replace(/"/g, '&quot;').replace(/'/g, '&#x27;').replace(/\//g, '&#x2F;');
    }

    function stripTags(str) {
        if (typeof str !== 'string') return str;
        return str.replace(/<[^>]*>/g, '');
    }

    // ============================================================
    // INPUT VALIDATION
    // ============================================================
    var Validators = {
        email: function(v) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v); },
        phone: function(v) { return v === '' || /^\+?[0-9\s\-()]{7,15}$/.test(v); },
        cnic: function(v) { return v === '' || /^[0-9]{5}-[0-9]{7}-[0-9]$/.test(v); },
        name: function(v) { return v && v.length >= 2 && v.length <= 100 && /^[a-zA-Z\s.\-']+$/.test(v); },
        percentage: function(v) { var n = parseFloat(v); return !isNaN(n) && n >= 0 && n <= 100; },
        date: function(v) { return v === '' || /^\d{4}-\d{2}-\d{2}$/.test(v); },
        time: function(v) { return v === '' || /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(v); },
        required: function(v) { return v && String(v).trim().length > 0; },
        maxLength: function(v, max) { return String(v).length <= max; },
        minLength: function(v, min) { return String(v).length >= min; }
    };

    function validateField(value, rules) {
        var errors = [];
        rules.forEach(function(rule) {
            if (rule === 'required' && !Validators.required(value)) {
                errors.push('This field is required');
            } else if (rule === 'email' && value && !Validators.email(value)) {
                errors.push('Invalid email format');
            } else if (rule === 'phone' && value && !Validators.phone(value)) {
                errors.push('Invalid phone number');
            } else if (rule === 'cnic' && value && !Validators.cnic(value)) {
                errors.push('CNIC must be in format XXXXX-XXXXXXX-X');
            } else if (rule === 'name' && value && !Validators.name(value)) {
                errors.push('Name must be 2-100 characters, letters only');
            } else if (rule === 'percentage' && value !== '' && !Validators.percentage(value)) {
                errors.push('Must be between 0 and 100');
            } else if (rule === 'date' && value && !Validators.date(value)) {
                errors.push('Date must be in YYYY-MM-DD format');
            } else if (typeof rule === 'object' && rule.type === 'maxLength' && !Validators.maxLength(value, rule.value)) {
                errors.push('Maximum ' + rule.value + ' characters');
            } else if (typeof rule === 'object' && rule.type === 'minLength' && !Validators.minLength(value, rule.value)) {
                errors.push('Minimum ' + rule.value + ' characters');
            }
        });
        return errors;
    }

    // ============================================================
    // PASSWORD SECURITY
    // ============================================================
    function checkPasswordStrength(password) {
        var score = 0;
        var feedback = [];

        if (password.length >= CONFIG.passwordMinLength) score++;
        else feedback.push('At least ' + CONFIG.passwordMinLength + ' characters');

        if (/[a-z]/.test(password)) score++;
        else feedback.push('Include lowercase letter');

        if (/[A-Z]/.test(password)) score++;
        else feedback.push('Include uppercase letter');

        if (/[0-9]/.test(password)) score++;
        else feedback.push('Include a number');

        if (/[^a-zA-Z0-9]/.test(password)) score++;
        else feedback.push('Include a special character');

        if (password.length >= 12) score++;

        var strength = score <= 2 ? 'weak' : (score <= 4 ? 'medium' : 'strong');
        return { score: score, strength: strength, feedback: feedback, valid: score >= 4 };
    }

    // ============================================================
    // RATE LIMITING (Client-side brute force protection)
    // ============================================================
    function getLoginAttempts() {
        try {
            var data = localStorage.getItem(CONFIG.loginAttemptsKey);
            return data ? JSON.parse(data) : { count: 0, lockedUntil: 0 };
        } catch (e) {
            return { count: 0, lockedUntil: 0 };
        }
    }

    function recordLoginAttempt(success) {
        var attempts = getLoginAttempts();
        if (success) {
            localStorage.removeItem(CONFIG.loginAttemptsKey);
            return true;
        }
        attempts.count++;
        if (attempts.count >= CONFIG.maxLoginAttempts) {
            attempts.lockedUntil = Date.now() + CONFIG.lockoutDuration;
        }
        localStorage.setItem(CONFIG.loginAttemptsKey, JSON.stringify(attempts));
        return attempts.count < CONFIG.maxLoginAttempts;
    }

    function isLockedOut() {
        var attempts = getLoginAttempts();
        if (attempts.lockedUntil > Date.now()) {
            var remaining = Math.ceil((attempts.lockedUntil - Date.now()) / 60000);
            return { locked: true, remaining: remaining };
        }
        if (attempts.lockedUntil > 0 && attempts.lockedUntil <= Date.now()) {
            localStorage.removeItem(CONFIG.loginAttemptsKey);
        }
        return { locked: false };
    }

    function getRemainingAttempts() {
        var attempts = getLoginAttempts();
        return Math.max(0, CONFIG.maxLoginAttempts - attempts.count);
    }

    // ============================================================
    // SESSION MANAGEMENT
    // ============================================================
    var sessionTimer = null;
    var inactivityTimer = null;
    var onSessionExpired = null;
    var onInactivityWarning = null;

    function startSession() {
        resetSessionTimers();
        // Activity listeners
        ['mousedown', 'keydown', 'scroll', 'touchstart', 'click'].forEach(function(evt) {
            document.addEventListener(evt, resetInactivityTimer, true);
        });
    }

    function resetSessionTimers() {
        clearTimeout(sessionTimer);
        clearTimeout(inactivityTimer);

        sessionTimer = setTimeout(function() {
            if (onSessionExpired) onSessionExpired();
            else handleSessionExpiry();
        }, CONFIG.sessionTimeout);

        resetInactivityTimer();
    }

    function resetInactivityTimer() {
        clearTimeout(inactivityTimer);
        inactivityTimer = setTimeout(function() {
            if (onInactivityWarning) onInactivityWarning();
            else handleInactivityWarning();
        }, CONFIG.inactivityTimeout);
    }

    function handleSessionExpiry() {
        console.warn('Session expired due to timeout');
        localStorage.removeItem(CONFIG.sessionKey);
        localStorage.removeItem(CONFIG.userKey);
        localStorage.removeItem(CONFIG.csrfTokenKey);
        window.location.href = 'login.html?reason=session_expired';
    }

    function handleInactivityWarning() {
        var warning = document.createElement('div');
        warning.id = 'inactivityWarning';
        warning.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.8);z-index:9999;display:flex;align-items:center;justify-content:center;';
        warning.innerHTML = '<div style="background:#18181b;border:1px solid #27272a;padding:32px;text-align:center;max-width:400px;">' +
            '<p style="font-family:Playfair Display,serif;color:#e4e4e7;font-size:14px;margin-bottom:8px;">Session Expiring Soon</p>' +
            '<p style="font-family:JetBrains Mono,monospace;color:#71717a;font-size:10px;margin-bottom:20px;">Your session will expire due to inactivity.</p>' +
            '<button onclick="Security.extendSession();this.parentElement.parentElement.remove();" style="background:#8b0000;color:#e4e4e7;padding:10px 24px;font-family:JetBrains Mono,monospace;font-size:10px;letter-spacing:0.1em;text-transform:uppercase;border:none;cursor:pointer;">CONTINUE SESSION</button>' +
            '</div>';
        document.body.appendChild(warning);
    }

    function extendSession() {
        resetSessionTimers();
    }

    function destroySession() {
        clearTimeout(sessionTimer);
        clearTimeout(inactivityTimer);
        localStorage.removeItem(CONFIG.sessionKey);
        localStorage.removeItem(CONFIG.userKey);
        localStorage.removeItem(CONFIG.csrfTokenKey);
    }

    // ============================================================
    // CSRF PROTECTION
    // ============================================================
    function generateCSRFToken() {
        var array = new Uint8Array(32);
        (window.crypto || window.msCrypto).getRandomValues(array);
        var token = Array.from(array).map(function(b) { return b.toString(16).padStart(2, '0'); }).join('');
        localStorage.setItem(CONFIG.csrfTokenKey, token);
        return token;
    }

    function getCSRFToken() {
        var token = localStorage.getItem(CONFIG.csrfTokenKey);
        if (!token) token = generateCSRFToken();
        return token;
    }

    function validateCSRFToken(token) {
        return token === getCSRFToken();
    }

    // ============================================================
    // LOCAL STORAGE INTEGRITY
    // ============================================================
    function signData(data) {
        var str = typeof data === 'string' ? data : JSON.stringify(data);
        var hash = 0;
        for (var i = 0; i < str.length; i++) {
            var char = str.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return hash.toString(36);
    }

    function storeSecure(key, data) {
        var payload = {
            data: data,
            signature: signData(data),
            timestamp: Date.now()
        };
        localStorage.setItem(key, JSON.stringify(payload));
    }

    function retrieveSecure(key) {
        try {
            var raw = localStorage.getItem(key);
            if (!raw) return null;
            var payload = JSON.parse(raw);
            if (!payload.data || !payload.signature || !payload.timestamp) return null;
            // Check tampering
            if (signData(payload.data) !== payload.signature) {
                console.warn('Data integrity check failed for key:', key);
                localStorage.removeItem(key);
                return null;
            }
            // Check staleness (older than 24 hours)
            if (Date.now() - payload.timestamp > 24 * 60 * 60 * 1000) {
                console.warn('Data stale for key:', key);
                localStorage.removeItem(key);
                return null;
            }
            return payload.data;
        } catch (e) {
            return null;
        }
    }

    // ============================================================
    // AUDIT LOGGING (Client-side)
    // ============================================================
    var auditQueue = [];

    function auditLog(eventType, details) {
        var entry = {
            event: eventType,
            details: details || {},
            timestamp: new Date().toISOString(),
            userAgent: navigator.userAgent.substring(0, 100),
            url: window.location.href,
            csrfToken: getCSRFToken()
        };
        auditQueue.push(entry);

        // Also log to console in development
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log('[AUDIT]', eventType, details);
        }

        // Flush to Supabase if available
        if (typeof supabase !== 'undefined' && supabase && supabase.from) {
            flushAuditLog();
        }
    }

    async function flushAuditLog() {
        if (auditQueue.length === 0) return;
        var entries = auditQueue.splice(0, auditQueue.length);
        try {
            await supabase.from('audit_log').insert(entries.map(function(e) {
                return {
                    event_type: e.event,
                    details: e.details,
                    ip_address: '',
                    created_at: e.timestamp
                };
            }));
        } catch (err) {
            // Put back in queue on failure
            auditQueue = entries.concat(auditQueue);
            console.warn('Audit log flush failed:', err);
        }
    }

    // ============================================================
    // SECURE ERROR HANDLING
    // ============================================================
    function safeError(err, context) {
        // Never expose stack traces or internal details
        var safeMessage = 'An unexpected error occurred.';
        if (err && err.message) {
            // Only expose known safe error messages
            var safeErrors = [
                'Network error',
                'Session expired',
                'Invalid input',
                'Permission denied',
                'Resource not found',
                'Rate limit exceeded'
            ];
            for (var i = 0; i < safeErrors.length; i++) {
                if (err.message.indexOf(safeErrors[i]) !== -1) {
                    safeMessage = err.message;
                    break;
                }
            }
        }
        // Log full error internally
        console.error('[SECURE ERROR]', context, err);
        // Audit log the full error
        auditLog('error', { context: context, message: err ? err.message : 'Unknown' });
        return safeMessage;
    }

    // ============================================================
    // REQUEST SECURITY
    // ============================================================
    function sanitizeRequest(data) {
        return sanitizeObject(data);
    }

    function validateRequest(data, schema) {
        var errors = {};
        Object.keys(schema).forEach(function(field) {
            var rules = schema[field];
            var value = data[field];
            var fieldErrors = validateField(value, rules);
            if (fieldErrors.length > 0) {
                errors[field] = fieldErrors;
            }
        });
        return { valid: Object.keys(errors).length === 0, errors: errors };
    }

    // ============================================================
    // ORIGIN VALIDATION
    // ============================================================
    function validateOrigin(origin) {
        return CONFIG.allowedOrigins.indexOf(origin) !== -1;
    }

    // ============================================================
    // INITIALIZATION
    // ============================================================
    function init(options) {
        if (options) {
            if (options.sessionTimeout) CONFIG.sessionTimeout = options.sessionTimeout;
            if (options.inactivityTimeout) CONFIG.inactivityTimeout = options.inactivityTimeout;
            if (options.onSessionExpired) onSessionExpired = options.onSessionExpired;
            if (options.onInactivityWarning) onInactivityWarning = options.onInactivityWarning;
        }
        generateCSRFToken();
        startSession();

        // Global error handler
        window.addEventListener('error', function(e) {
            auditLog('js_error', { message: e.message, filename: e.filename, line: e.lineno });
        });

        window.addEventListener('unhandledrejection', function(e) {
            auditLog('unhandled_promise', { reason: String(e.reason).substring(0, 200) });
        });
    }

    // ============================================================
    // PUBLIC API
    // ============================================================
    return {
        // Sanitization
        sanitize: sanitize,
        sanitizeObject: sanitizeObject,
        sanitizeArray: sanitizeArray,
        escapeHtml: escapeHtml,
        stripTags: stripTags,

        // Validation
        validateField: validateField,
        validateRequest: validateRequest,
        Validators: Validators,

        // Password
        checkPasswordStrength: checkPasswordStrength,

        // Rate Limiting
        isLockedOut: isLockedOut,
        recordLoginAttempt: recordLoginAttempt,
        getRemainingAttempts: getRemainingAttempts,

        // Session
        startSession: startSession,
        extendSession: extendSession,
        destroySession: destroySession,
        resetSessionTimers: resetSessionTimers,
        CONFIG: CONFIG,

        // CSRF
        getCSRFToken: getCSRFToken,
        validateCSRFToken: validateCSRFToken,

        // Storage
        storeSecure: storeSecure,
        retrieveSecure: retrieveSecure,

        // Audit
        auditLog: auditLog,
        flushAuditLog: flushAuditLog,

        // Error Handling
        safeError: safeError,

        // Request Security
        sanitizeRequest: sanitizeRequest,

        // Init
        init: init
    };
})();
