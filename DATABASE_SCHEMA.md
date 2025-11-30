# DATABASE SCHEMA - EDUCATIONAL ERP SYSTEM

## OVERVIEW
PostgreSQL database with 50+ tables supporting:
- Multi-program institution (B.Com, B.Sc, MBA, etc.)
- Hybrid RBAC (Department + Class + Subject based access)
- Dynamic fee management with scholarships
- Lab batching system
- Flexible result templates
- Division management (A, B, C divisions)

## CORE TABLES

### 1. AUTHENTICATION & USERS

```sql
-- Users table (Staff, Students, Parents)
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    user_type ENUM('staff', 'student', 'parent') NOT NULL,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    last_login_at TIMESTAMP,
    email_verified_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Roles table
CREATE TABLE roles (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, -- 'principal', 'hod_commerce', 'class_teacher', etc.
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    department_id BIGINT REFERENCES departments(id), -- NULL for institution-wide roles
    is_system_role BOOLEAN DEFAULT FALSE, -- Cannot be deleted
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Role Assignment
CREATE TABLE user_roles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by BIGINT REFERENCES users(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP, -- Optional role expiry
    UNIQUE(user_id, role_id)
);

-- Permissions table
CREATE TABLE permissions (
    id BIGSERIAL PRIMARY KEY,
    module VARCHAR(100) NOT NULL, -- 'student_management', 'fee_collection', etc.
    feature VARCHAR(100) NOT NULL, -- 'student_list', 'collect_fees', etc.
    action VARCHAR(50) NOT NULL, -- 'view', 'add', 'edit', 'delete'
    name VARCHAR(255) NOT NULL, -- 'student_management.student_list.view'
    description TEXT,
    UNIQUE(module, feature, action)
);

-- Role Permissions
CREATE TABLE role_permissions (
    id BIGSERIAL PRIMARY KEY,
    role_id BIGINT REFERENCES roles(id) ON DELETE CASCADE,
    permission_id BIGINT REFERENCES permissions(id) ON DELETE CASCADE,
    granted_by BIGINT REFERENCES users(id),
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, permission_id)
);
```

### 2. ACADEMIC STRUCTURE

```sql
-- Departments
CREATE TABLE departments (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, -- 'Commerce', 'Science', 'Management'
    code VARCHAR(20) UNIQUE NOT NULL, -- 'COM', 'SCI', 'MGT'
    hod_user_id BIGINT REFERENCES users(id), -- Head of Department
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Programs (B.Com, B.Sc CS, MBA, etc.)
CREATE TABLE programs (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- 'Bachelor of Commerce', 'Bachelor of Science in Computer Science'
    short_name VARCHAR(100) NOT NULL, -- 'B.Com', 'B.Sc CS'
    code VARCHAR(20) UNIQUE NOT NULL, -- 'BCOM', 'BSCCS'
    
    -- University Information (Flexible)
    university_affiliation VARCHAR(100), -- 'Savitribai Phule Pune University', 'Mumbai University', etc.
    university_program_code VARCHAR(20), -- For any university pattern if needed
    
    department_id BIGINT REFERENCES departments(id),
    duration_years INTEGER NOT NULL, -- 3 for UG, 2 for PG
    total_semesters INTEGER, -- 6 for 3-year, 4 for 2-year
    program_type ENUM('undergraduate', 'postgraduate', 'diploma') NOT NULL,
    
    -- Grading System
    default_grade_scale_name VARCHAR(100) DEFAULT 'SPPU 10-Point', -- Which grading system to use
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Academic Years (FY, SY, TY / Sem 1-8)
CREATE TABLE academic_years (
    id BIGSERIAL PRIMARY KEY,
    program_id BIGINT REFERENCES programs(id),
    year_number INTEGER NOT NULL, -- 1, 2, 3
    year_name VARCHAR(50) NOT NULL, -- 'FY', 'SY', 'TY'
    
    semester_start INTEGER, -- 1 (for FY: Sem 1, 2)
    semester_end INTEGER, -- 2 (for FY: Sem 1, 2)
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(program_id, year_number)
);

-- Roll Number Sequence Tracking
CREATE TABLE roll_number_sequences (
    program_id BIGINT REFERENCES programs(id),
    academic_year VARCHAR(20),
    division_name VARCHAR(10),
    last_number INTEGER DEFAULT 0,
    PRIMARY KEY(program_id, academic_year, division_name)
);

-- Academic Year Transitions
CREATE TABLE academic_year_transitions (
    id BIGSERIAL PRIMARY KEY,
    from_year VARCHAR(20),
    to_year VARCHAR(20),
    transition_date DATE,
    status ENUM('planned', 'in_progress', 'completed') DEFAULT 'planned',
    created_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Divisions (A, B, C, D)
CREATE TABLE divisions (
    id BIGSERIAL PRIMARY KEY,
    academic_year_id BIGINT REFERENCES academic_years(id),
    division_name VARCHAR(10) NOT NULL, -- 'A', 'B', 'C'
    max_students INTEGER DEFAULT 60,
    class_teacher_id BIGINT REFERENCES users(id), -- Class Teacher
    classroom VARCHAR(50), -- 'Room 101', 'Hall A'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(academic_year_id, division_name)
);

-- Subjects (Flexible - Admin has complete control over codes)
CREATE TABLE subjects (
    id BIGSERIAL PRIMARY KEY,
    
    -- Basic Information (Admin enters freely)
    name VARCHAR(255) NOT NULL, -- 'Financial Accounting Theory'
    subject_code VARCHAR(50) NOT NULL, -- 'CS-101-T', 'UBCOMFI.1', 'FIN001', etc.
    short_name VARCHAR(100), -- 'Fin. Acc.', 'Data Structures'
    description TEXT,
    
    -- Academic Structure
    program_id BIGINT REFERENCES programs(id),
    academic_year VARCHAR(20) NOT NULL, -- '2025-26', '2026-27'
    semester_number INTEGER NOT NULL, -- 1, 2, 3, 4, 5, 6
    
    -- Subject Type
    subject_type ENUM('theory', 'practical', 'project', 'viva', 'combined') NOT NULL,
    
    -- Linked Subjects (for practicals linked to theory)
    parent_subject_id BIGINT REFERENCES subjects(id), -- CS-102-P links to CS-101-T
    
    -- Academic Configuration
    credits INTEGER DEFAULT 0,
    lecture_hours_per_week INTEGER DEFAULT 0,
    practical_hours_per_week INTEGER DEFAULT 0,
    
    -- Marks Configuration (Admin configurable)
    max_marks INTEGER DEFAULT 100,
    internal_marks INTEGER DEFAULT 40,
    external_marks INTEGER DEFAULT 60,
    
    -- Pass Criteria (Admin configurable)
    min_marks_to_pass INTEGER DEFAULT 40,
    min_internal_marks INTEGER DEFAULT 16,
    min_external_marks INTEGER DEFAULT 24,
    
    -- Display and Organization
    display_order INTEGER DEFAULT 0, -- For ordering subjects in lists
    
    -- Status
    is_elective BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    deleted_at TIMESTAMP NULL, -- Soft delete
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Program-scoped unique constraint
    UNIQUE(program_id, subject_code)
);

-- Subject Practical Links (for combined practicals like CS-233 serving CS-231 + CS-232)
CREATE TABLE subject_practical_links (
    id BIGSERIAL PRIMARY KEY,
    practical_subject_id BIGINT REFERENCES subjects(id), -- CS-233
    theory_subject_id BIGINT REFERENCES subjects(id),    -- CS-231 or CS-232
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(practical_subject_id, theory_subject_id)
);

-- Flexible Grade Scales (Admin can configure any grading system)
CREATE TABLE grade_scales (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL, -- 'SPPU 10-Point', 'Mumbai University 7-Point', 'Custom'
    grade VARCHAR(5) NOT NULL, -- 'O', 'A+', 'A', 'B+', 'B', 'C', 'D', 'F'
    grade_points DECIMAL(3,1) NOT NULL, -- 10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 0.0
    min_percentage DECIMAL(5,2) NOT NULL, -- 80.00, 70.00, 60.00, etc.
    max_percentage DECIMAL(5,2) NOT NULL, -- 100.00, 79.99, 69.99, etc.
    description VARCHAR(100), -- 'Outstanding', 'Excellent', etc.
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subject Teachers Assignment
CREATE TABLE subject_teachers (
    id BIGSERIAL PRIMARY KEY,
    subject_id BIGINT REFERENCES subjects(id),
    teacher_id BIGINT REFERENCES users(id),
    division_id BIGINT REFERENCES divisions(id), -- NULL if teaches all divisions
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    assigned_by BIGINT REFERENCES users(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(subject_id, teacher_id, division_id, academic_session_id)
);
```

### 3. STUDENT MANAGEMENT

```sql
-- Academic Sessions (2025-26, 2026-27)
CREATE TABLE academic_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_name VARCHAR(20) UNIQUE NOT NULL, -- '2025-26'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Students
CREATE TABLE students (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    admission_number VARCHAR(50) UNIQUE NOT NULL,
    roll_number VARCHAR(50) UNIQUE NOT NULL, -- 2025/FYBCOM/A/001
    prn VARCHAR(50) UNIQUE, -- University PRN (Permanent Registration Number)
    university_seat_number VARCHAR(20), -- University exam seat number
    
    -- Personal Information
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender ENUM('male', 'female', 'other') NOT NULL,
    blood_group VARCHAR(5),
    religion VARCHAR(50),
    caste VARCHAR(50),
    category ENUM('general', 'obc', 'sc', 'st', 'vjnt', 'nt', 'sbc') DEFAULT 'general',
    aadhar_number VARCHAR(12) UNIQUE,
    
    -- Contact Information
    mobile_number VARCHAR(15),
    email VARCHAR(255),
    current_address TEXT,
    permanent_address TEXT,
    
    -- Academic Information
    program_id BIGINT REFERENCES programs(id),
    academic_year VARCHAR(20) NOT NULL, -- '2025-26'
    division_id BIGINT REFERENCES divisions(id),
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    
    -- Status
    student_status ENUM('active', 'graduated', 'dropped', 'suspended', 'tc_issued') DEFAULT 'active',
    admission_date DATE NOT NULL,
    
    -- Documents
    photo_path VARCHAR(500),
    signature_path VARCHAR(500),
    
    -- Soft delete
    deleted_at TIMESTAMP NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Parent/Guardian Information
CREATE TABLE student_guardians (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id) ON DELETE CASCADE,
    guardian_type ENUM('father', 'mother', 'guardian') NOT NULL,
    
    full_name VARCHAR(255) NOT NULL,
    occupation VARCHAR(100),
    annual_income DECIMAL(12,2),
    mobile_number VARCHAR(15),
    email VARCHAR(255),
    photo_path VARCHAR(500),
    
    -- Guardian-specific fields
    relation VARCHAR(50), -- Only for guardian type
    address TEXT,
    
    is_primary_contact BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Student Enrollment (tracks year-wise enrollment)
CREATE TABLE student_enrollments (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    academic_year_id BIGINT REFERENCES academic_years(id),
    division_id BIGINT REFERENCES divisions(id),
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    enrollment_date DATE NOT NULL,
    status ENUM('enrolled', 'promoted', 'detained', 'dropped') DEFAULT 'enrolled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, academic_year_id, academic_session_id)
);
```

### 4. FEE MANAGEMENT

```sql
-- Fee Heads (TF, PA, LJ, SFP, AC, VACF, etc.)
CREATE TABLE fee_heads (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- 'Tuition Fee', 'Lab Fee'
    code VARCHAR(20) UNIQUE NOT NULL, -- 'TF', 'PA'
    description TEXT,
    fee_category ENUM('academic', 'administrative', 'refundable', 'exam', 'other') DEFAULT 'academic',
    is_refundable BOOLEAN DEFAULT FALSE,
    is_mandatory BOOLEAN DEFAULT TRUE,
    tax_applicable BOOLEAN DEFAULT FALSE,
    tax_percentage DECIMAL(5,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fee Structures (per Program per Year)
CREATE TABLE fee_structures (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- 'FY B.Com Fees 2025-26'
    program_id BIGINT REFERENCES programs(id),
    academic_year VARCHAR(20) NOT NULL, -- '2025-26'
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    structure_type ENUM('regular', 'scholarship', 'management_quota', 'nri') DEFAULT 'regular',
    total_amount DECIMAL(10,2) NOT NULL,
    number_of_installments INTEGER DEFAULT 2,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fee Structure Items (Fee Head + Amount mapping)
CREATE TABLE fee_structure_items (
    id BIGSERIAL PRIMARY KEY,
    fee_structure_id BIGINT REFERENCES fee_structures(id) ON DELETE CASCADE,
    fee_head_id BIGINT REFERENCES fee_heads(id),
    amount DECIMAL(10,2) NOT NULL,
    is_one_time BOOLEAN DEFAULT FALSE, -- Paid only in first year
    payment_frequency ENUM('annual', 'semester', 'monthly') DEFAULT 'annual',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Installments Configuration
CREATE TABLE installments (
    id BIGSERIAL PRIMARY KEY,
    fee_structure_id BIGINT REFERENCES fee_structures(id) ON DELETE CASCADE,
    installment_number INTEGER NOT NULL,
    installment_name VARCHAR(100) NOT NULL, -- '1st Installment', '2nd Installment'
    due_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    late_fee_type ENUM('none', 'flat', 'percentage', 'per_day') DEFAULT 'none',
    late_fee_amount DECIMAL(10,2) DEFAULT 0,
    grace_period_days INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(fee_structure_id, installment_number)
);

-- Installment Items (which fee heads are in which installment)
CREATE TABLE installment_items (
    id BIGSERIAL PRIMARY KEY,
    installment_id BIGINT REFERENCES installments(id) ON DELETE CASCADE,
    fee_head_id BIGINT REFERENCES fee_heads(id),
    amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Student Fee Assignment
CREATE TABLE student_fees (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    fee_structure_id BIGINT REFERENCES fee_structures(id),
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    total_amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) DEFAULT 0,
    balance_amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'partial', 'paid', 'overdue') DEFAULT 'pending',
    assigned_date DATE NOT NULL,
    assigned_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, academic_session_id)
);

-- Scholarships & Concessions
CREATE TABLE scholarships (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- 'Merit Scholarship', 'SC/ST Scholarship'
    code VARCHAR(50) UNIQUE NOT NULL, -- 'MERIT50', 'SCST100'
    scholarship_type ENUM('merit', 'need_based', 'government', 'sports', 'cultural', 'staff_ward') NOT NULL,
    discount_type ENUM('percentage', 'fixed_amount') NOT NULL,
    discount_value DECIMAL(10,2) NOT NULL, -- 50 (for 50%) or 10000 (for ₹10,000)
    applicable_fee_heads JSON, -- Array of fee_head_ids or 'all'
    eligibility_criteria TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Student Scholarship Assignment
CREATE TABLE student_scholarships (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    scholarship_id BIGINT REFERENCES scholarships(id),
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    discount_amount DECIMAL(10,2) NOT NULL,
    applied_date DATE NOT NULL,
    applied_by BIGINT REFERENCES users(id),
    approval_status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    approved_by BIGINT REFERENCES users(id),
    approved_date DATE,
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fee Payments
CREATE TABLE fee_payments (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    student_fee_id BIGINT REFERENCES student_fees(id),
    payment_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_mode ENUM('cash', 'cheque', 'online', 'bank_transfer', 'dd') NOT NULL,
    
    -- Payment Details
    transaction_id VARCHAR(255), -- For online payments
    reference_number VARCHAR(255), -- Cheque no, DD no, Bank ref
    bank_name VARCHAR(255),
    razorpay_payment_id VARCHAR(255), -- Razorpay payment ID
    
    -- Receipt Information
    receipt_number VARCHAR(100) UNIQUE NOT NULL,
    
    -- Staff Information
    collected_by BIGINT REFERENCES users(id),
    
    -- Status
    payment_status ENUM('pending', 'verified', 'failed', 'refunded') DEFAULT 'verified',
    reconciliation_status ENUM('pending', 'matched', 'disputed', 'refunded') DEFAULT 'pending',
    reconciled_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fee Payment Items (breakdown of payment per fee head)
CREATE TABLE fee_payment_items (
    id BIGSERIAL PRIMARY KEY,
    fee_payment_id BIGINT REFERENCES fee_payments(id) ON DELETE CASCADE,
    fee_head_id BIGINT REFERENCES fee_heads(id),
    amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 5. LAB MANAGEMENT

```sql
-- Lab Resources (Computer Labs, Equipment)
CREATE TABLE lab_resources (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- 'Computer Lab 1', 'Physics Lab'
    code VARCHAR(50) UNIQUE NOT NULL, -- 'COMP_LAB_1', 'PHY_LAB'
    location VARCHAR(255), -- 'Ground Floor, Room 101'
    capacity INTEGER NOT NULL, -- 25 computers, 30 students
    equipment_details JSON, -- Array of equipment with quantities
    lab_type ENUM('computer', 'physics', 'chemistry', 'biology', 'language', 'other') NOT NULL,
    lab_incharge_id BIGINT REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lab Subjects (Programming Lab, DBMS Lab, etc.)
CREATE TABLE lab_subjects (
    id BIGSERIAL PRIMARY KEY,
    subject_id BIGINT REFERENCES subjects(id),
    lab_type ENUM('computer', 'physics', 'chemistry', 'biology', 'language', 'other') NOT NULL,
    required_equipment JSON, -- What equipment is needed
    session_duration_minutes INTEGER DEFAULT 120, -- 2 hours
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lab Sessions (Time slots for lab subjects)
CREATE TABLE lab_sessions (
    id BIGSERIAL PRIMARY KEY,
    lab_subject_id BIGINT REFERENCES lab_subjects(id),
    division_id BIGINT REFERENCES divisions(id),
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    
    -- Schedule
    day_of_week INTEGER NOT NULL, -- 1=Monday, 2=Tuesday, etc.
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    
    -- Batch Configuration
    total_students INTEGER NOT NULL,
    students_per_batch INTEGER NOT NULL,
    number_of_batches INTEGER NOT NULL,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lab Batches (Student groups for lab sessions)
CREATE TABLE lab_batches (
    id BIGSERIAL PRIMARY KEY,
    lab_session_id BIGINT REFERENCES lab_sessions(id),
    batch_number INTEGER NOT NULL,
    batch_name VARCHAR(100) NOT NULL, -- 'Batch 1', 'Batch A'
    lab_resource_id BIGINT REFERENCES lab_resources(id), -- Which lab room
    max_students INTEGER NOT NULL,
    current_students INTEGER DEFAULT 0,
    lab_instructor_id BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(lab_session_id, batch_number)
);

-- Student Lab Batch Assignment
CREATE TABLE student_lab_batches (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    lab_batch_id BIGINT REFERENCES lab_batches(id),
    assigned_date DATE NOT NULL,
    assigned_by BIGINT REFERENCES users(id),
    status ENUM('active', 'transferred', 'dropped') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, lab_batch_id)
);
```

### 6. ATTENDANCE MANAGEMENT

```sql
-- Attendance Sessions (Daily time slots)
CREATE TABLE attendance_sessions (
    id BIGSERIAL PRIMARY KEY,
    division_id BIGINT REFERENCES divisions(id),
    subject_id BIGINT REFERENCES subjects(id),
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    session_date DATE NOT NULL,
    session_type ENUM('lecture', 'practical', 'tutorial') DEFAULT 'lecture',
    start_time TIME,
    end_time TIME,
    total_students INTEGER NOT NULL,
    present_students INTEGER DEFAULT 0,
    marked_by BIGINT REFERENCES users(id),
    marked_at TIMESTAMP,
    status ENUM('pending', 'marked', 'locked') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Student Attendance Records
CREATE TABLE student_attendance (
    id BIGSERIAL PRIMARY KEY,
    attendance_session_id BIGINT REFERENCES attendance_sessions(id),
    student_id BIGINT REFERENCES students(id),
    status ENUM('present', 'absent', 'late', 'excused') NOT NULL,
    marked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT,
    UNIQUE(attendance_session_id, student_id)
);

-- Lab Attendance (separate from lecture attendance)
CREATE TABLE lab_attendance (
    id BIGSERIAL PRIMARY KEY,
    lab_batch_id BIGINT REFERENCES lab_batches(id),
    student_id BIGINT REFERENCES students(id),
    session_date DATE NOT NULL,
    status ENUM('present', 'absent', 'late') NOT NULL,
    lab_instructor_id BIGINT REFERENCES users(id),
    marked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT,
    UNIQUE(lab_batch_id, student_id, session_date)
);
```

### 7. RESULTS & EXAMINATIONS

```sql
-- Assessment Types (Internal, External, Practical)
CREATE TABLE assessment_types (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL, -- 'Internal Assessment 1', 'Mid-term', 'Final Exam'
    code VARCHAR(20) UNIQUE NOT NULL, -- 'IA1', 'MID', 'FINAL'
    assessment_category ENUM('internal', 'external', 'practical', 'project') NOT NULL,
    max_marks INTEGER NOT NULL,
    weightage_percentage DECIMAL(5,2), -- Contribution to final marks
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Examinations
CREATE TABLE examinations (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- 'Semester 1 Final Exam'
    exam_type ENUM('internal', 'external', 'practical') NOT NULL,
    academic_year_id BIGINT REFERENCES academic_years(id),
    academic_session_id BIGINT REFERENCES academic_sessions(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    result_declaration_date DATE,
    status ENUM('scheduled', 'ongoing', 'completed', 'results_declared') DEFAULT 'scheduled',
    created_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exam Subjects (which subjects are in which exam)
CREATE TABLE exam_subjects (
    id BIGSERIAL PRIMARY KEY,
    examination_id BIGINT REFERENCES examinations(id),
    subject_id BIGINT REFERENCES subjects(id),
    exam_date DATE NOT NULL,
    start_time TIME NOT NULL,
    duration_minutes INTEGER NOT NULL,
    max_marks INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(examination_id, subject_id)
);

-- Student Marks
CREATE TABLE student_marks (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    exam_subject_id BIGINT REFERENCES exam_subjects(id),
    assessment_type_id BIGINT REFERENCES assessment_types(id),
    
    -- Marks Breakdown
    marks_obtained DECIMAL(6,2) NOT NULL,
    max_marks DECIMAL(6,2) NOT NULL,
    
    -- Additional fields for detailed marking
    internal_marks DECIMAL(6,2) DEFAULT 0,
    external_marks DECIMAL(6,2) DEFAULT 0,
    practical_marks DECIMAL(6,2) DEFAULT 0,
    
    -- Status
    is_absent BOOLEAN DEFAULT FALSE,
    is_grace_marks BOOLEAN DEFAULT FALSE,
    grace_marks DECIMAL(6,2) DEFAULT 0,
    
    -- Entry Information
    entered_by BIGINT REFERENCES users(id),
    entered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by BIGINT REFERENCES users(id),
    approved_at TIMESTAMP,
    
    -- Audit
    last_modified_by BIGINT REFERENCES users(id),
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(student_id, exam_subject_id, assessment_type_id)
);

-- Grading Systems (Marks, CGPA, Hybrid)
CREATE TABLE grading_systems (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL, -- 'B.Com Marks System', 'B.Sc CGPA System'
    program_id BIGINT REFERENCES programs(id),
    system_type ENUM('marks', 'cgpa', 'hybrid') NOT NULL,
    
    -- Grade Scale (for CGPA system)
    grade_scale JSON, -- [{"grade":"O","points":10,"min_marks":80,"max_marks":100}, ...]
    
    -- Pass Criteria
    min_marks_per_subject DECIMAL(5,2) DEFAULT 40,
    min_overall_percentage DECIMAL(5,2) DEFAULT 40,
    min_cgpa DECIMAL(3,2) DEFAULT 4.0,
    
    -- ATKT Rules
    max_atkt_subjects INTEGER DEFAULT 2,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Result Templates (Configurable marksheet templates)
CREATE TABLE result_templates (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- 'B.Com Semester Marksheet'
    program_id BIGINT REFERENCES programs(id),
    grading_system_id BIGINT REFERENCES grading_systems(id),
    template_type ENUM('semester', 'annual', 'consolidated') NOT NULL,
    
    -- Template Configuration
    header_config JSON, -- College logo, name, university affiliation
    student_fields JSON, -- Which student fields to show
    subject_fields JSON, -- Which subject/marks fields to show
    calculation_rules JSON, -- Pass/fail logic, class determination
    layout_config JSON, -- Styling, fonts, colors, layout
    signature_config JSON, -- Principal, Controller, HOD signatures
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Generated Results (Final calculated results)
CREATE TABLE student_results (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    examination_id BIGINT REFERENCES examinations(id),
    result_template_id BIGINT REFERENCES result_templates(id),
    
    -- Calculated Results
    total_marks DECIMAL(8,2),
    marks_obtained DECIMAL(8,2),
    percentage DECIMAL(5,2),
    sgpa DECIMAL(4,2), -- Semester GPA
    cgpa DECIMAL(4,2), -- Cumulative GPA
    
    -- Result Status
    result_status ENUM('pass', 'fail', 'atkt', 'promoted', 'detained') NOT NULL,
    class_obtained VARCHAR(100), -- 'First Class', 'Distinction', etc.
    
    -- Marksheet
    marksheet_number VARCHAR(100) UNIQUE,
    marksheet_generated_at TIMESTAMP,
    marksheet_path VARCHAR(500), -- PDF file path
    
    -- Approval
    approved_by BIGINT REFERENCES users(id),
    approved_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 8. LIBRARY MANAGEMENT

```sql
-- Library Books
CREATE TABLE library_books (
    id BIGSERIAL PRIMARY KEY,
    isbn VARCHAR(20) UNIQUE,
    title VARCHAR(500) NOT NULL,
    author VARCHAR(255) NOT NULL,
    publisher VARCHAR(255),
    publication_year INTEGER,
    edition VARCHAR(50),
    category VARCHAR(100), -- 'Computer Science', 'Commerce', 'General'
    
    -- Physical Details
    total_copies INTEGER NOT NULL DEFAULT 1,
    available_copies INTEGER NOT NULL DEFAULT 1,
    rack_number VARCHAR(50),
    
    -- Pricing
    price DECIMAL(8,2),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    added_date DATE DEFAULT CURRENT_DATE,
    added_by BIGINT REFERENCES users(id),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Book Issues
CREATE TABLE book_issues (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT REFERENCES library_books(id),
    student_id BIGINT REFERENCES students(id),
    
    -- Issue Details
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    return_date DATE,
    
    -- Fine Calculation
    fine_per_day DECIMAL(6,2) DEFAULT 2.00,
    total_fine DECIMAL(8,2) DEFAULT 0,
    fine_paid DECIMAL(8,2) DEFAULT 0,
    max_fine_amount DECIMAL(8,2) GENERATED ALWAYS AS (
        CASE WHEN (SELECT price FROM library_books WHERE id = book_issues.book_id) IS NOT NULL 
        THEN (SELECT price FROM library_books WHERE id = book_issues.book_id) * 2 
        ELSE 1000.00 END
    ) STORED,
    
    -- Status
    status ENUM('issued', 'returned', 'lost', 'damaged') DEFAULT 'issued',
    
    -- Staff
    issued_by BIGINT REFERENCES users(id),
    returned_to BIGINT REFERENCES users(id),
    
    -- Remarks
    issue_remarks TEXT,
    return_remarks TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 9. HR & PAYROLL

```sql
-- Staff Profiles
CREATE TABLE staff_profiles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    
    -- Personal Information
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender ENUM('male', 'female', 'other'),
    mobile_number VARCHAR(15),
    email VARCHAR(255),
    address TEXT,
    
    -- Employment Details
    department_id BIGINT REFERENCES departments(id),
    designation VARCHAR(100) NOT NULL, -- 'Assistant Professor', 'Associate Professor'
    employment_type ENUM('permanent', 'temporary', 'contract', 'visiting') DEFAULT 'permanent',
    joining_date DATE NOT NULL,
    
    -- Salary Information
    basic_salary DECIMAL(10,2) NOT NULL,
    grade_pay DECIMAL(10,2) DEFAULT 0,
    
    -- Bank Details
    bank_name VARCHAR(255),
    account_number VARCHAR(50),
    ifsc_code VARCHAR(20),
    
    -- Documents
    photo_path VARCHAR(500),
    
    -- Status
    status ENUM('active', 'inactive', 'resigned', 'terminated') DEFAULT 'active',
    deleted_at TIMESTAMP NULL, -- Soft delete
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Salary Components
CREATE TABLE salary_components (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL, -- 'Basic Salary', 'HRA', 'DA', 'PF', 'ESI'
    component_type ENUM('earning', 'deduction') NOT NULL,
    calculation_type ENUM('fixed', 'percentage', 'formula') NOT NULL,
    default_value DECIMAL(10,2) DEFAULT 0,
    is_mandatory BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Staff Salary Structure
CREATE TABLE staff_salary_structures (
    id BIGSERIAL PRIMARY KEY,
    staff_id BIGINT REFERENCES staff_profiles(id),
    salary_component_id BIGINT REFERENCES salary_components(id),
    amount DECIMAL(10,2) NOT NULL,
    effective_from DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Salary Processing
CREATE TABLE salary_payments (
    id BIGSERIAL PRIMARY KEY,
    staff_id BIGINT REFERENCES staff_profiles(id),
    pay_period_month INTEGER NOT NULL, -- 1-12
    pay_period_year INTEGER NOT NULL,
    
    -- Calculated Amounts
    gross_salary DECIMAL(10,2) NOT NULL,
    total_deductions DECIMAL(10,2) DEFAULT 0,
    net_salary DECIMAL(10,2) NOT NULL,
    
    -- Payment Details
    payment_date DATE,
    payment_mode ENUM('bank_transfer', 'cheque', 'cash') DEFAULT 'bank_transfer',
    transaction_reference VARCHAR(255),
    
    -- Status
    status ENUM('draft', 'approved', 'paid') DEFAULT 'draft',
    
    -- Approval
    processed_by BIGINT REFERENCES users(id),
    approved_by BIGINT REFERENCES users(id),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(staff_id, pay_period_month, pay_period_year)
);
```

### 10. REPORTS & AUDIT

```sql
-- Saved Reports (Dynamic Report Builder)
CREATE TABLE saved_reports (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    report_type VARCHAR(100) NOT NULL, -- 'student_list', 'fee_collection', etc.
    
    -- Report Configuration
    base_query VARCHAR(100) NOT NULL, -- 'students', 'fees', 'attendance'
    selected_columns JSON NOT NULL, -- Array of column names
    filters JSON, -- Filter conditions
    sorting JSON, -- Sort configuration
    grouping JSON, -- Group by configuration
    
    -- Access Control
    created_by BIGINT REFERENCES users(id),
    visibility ENUM('private', 'department', 'public') DEFAULT 'private',
    allowed_roles JSON, -- Array of role IDs that can access
    
    -- Usage
    last_run_at TIMESTAMP,
    run_count INTEGER DEFAULT 0,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Logs
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id),
    action VARCHAR(100) NOT NULL, -- 'create', 'update', 'delete', 'view'
    table_name VARCHAR(100) NOT NULL,
    record_id BIGINT,
    
    -- Change Details
    old_values JSON, -- Previous data
    new_values JSON, -- New data
    
    -- Request Details
    ip_address INET,
    user_agent TEXT,
    request_url TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System Settings
CREATE TABLE system_settings (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    setting_type ENUM('string', 'integer', 'boolean', 'json') DEFAULT 'string',
    is_public BOOLEAN DEFAULT FALSE, -- Can be accessed by frontend
    updated_by BIGINT REFERENCES users(id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

-- Permission Groups (Simplified RBAC)
CREATE TABLE permission_groups (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL, -- 'student_management', 'fee_collection'
    permissions JSON NOT NULL,   -- ['view_students', 'edit_students', 'delete_students']
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Role Permission Groups
CREATE TABLE role_permission_groups (
    role_id BIGINT REFERENCES roles(id),
    permission_group_id BIGINT REFERENCES permission_groups(id),
    PRIMARY KEY(role_id, permission_group_id)
);

-- Timetable System
CREATE TABLE timetable_slots (
    id BIGSERIAL PRIMARY KEY,
    division_id BIGINT REFERENCES divisions(id),
    subject_id BIGINT REFERENCES subjects(id),
    teacher_id BIGINT REFERENCES users(id),
    day_of_week INTEGER NOT NULL, -- 1-7
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    room_number VARCHAR(50),
    academic_year VARCHAR(20),
    UNIQUE(teacher_id, day_of_week, start_time, academic_year),
    UNIQUE(room_number, day_of_week, start_time, academic_year),
    UNIQUE(division_id, day_of_week, start_time, academic_year)
);

-- Student Promotions
CREATE TABLE student_promotions (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT REFERENCES students(id),
    from_academic_year VARCHAR(20),
    to_academic_year VARCHAR(20),
    from_program_id BIGINT REFERENCES programs(id),
    to_program_id BIGINT REFERENCES programs(id),
    promotion_status ENUM('promoted', 'detained', 'repeat') DEFAULT 'promoted',
    new_fee_structure_id BIGINT REFERENCES fee_structures(id),
    promoted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    promoted_by BIGINT REFERENCES users(id)
);

-- Report Table Permissions
CREATE TABLE report_table_permissions (
    role_id BIGINT REFERENCES roles(id),
    table_name VARCHAR(100),
    can_access BOOLEAN DEFAULT FALSE,
    PRIMARY KEY(role_id, table_name)
);

-- Data Backups
CREATE TABLE data_backups (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100),
    operation_type VARCHAR(50),
    backup_data JSONB,
    created_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exam Seat Allocations
CREATE TABLE exam_seat_allocations (
    id BIGSERIAL PRIMARY KEY,
    examination_id BIGINT REFERENCES examinations(id),
    student_id BIGINT REFERENCES students(id),
    room_number VARCHAR(50),
    seat_number VARCHAR(20),
    UNIQUE(examination_id, room_number, seat_number),
    UNIQUE(examination_id, student_id)
);

## VALIDATION CONSTRAINTS

```sql
-- Fee installment validation
ALTER TABLE installments ADD CONSTRAINT check_installment_total 
CHECK ((SELECT SUM(amount) FROM installments i2 WHERE i2.fee_structure_id = installments.fee_structure_id) <= 
       (SELECT total_amount FROM fee_structures WHERE id = installments.fee_structure_id));

-- Subject teacher workload tracking
ALTER TABLE subject_teachers ADD COLUMN workload_units DECIMAL(4,1) DEFAULT 0;
```

## TRIGGERS AND FUNCTIONS

```sql
-- Division capacity check
CREATE OR REPLACE FUNCTION check_division_enrollment()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM students WHERE division_id = NEW.division_id AND student_status = 'active' AND deleted_at IS NULL) >= 
       (SELECT max_students FROM divisions WHERE id = NEW.division_id) THEN
        RAISE EXCEPTION 'Division capacity exceeded';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER division_capacity_check 
BEFORE INSERT OR UPDATE ON students 
FOR EACH ROW EXECUTE FUNCTION check_division_enrollment();

-- Lab capacity check
CREATE OR REPLACE FUNCTION check_lab_capacity()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM student_lab_batches slb 
        JOIN lab_batches lb ON slb.lab_batch_id = lb.id 
        WHERE lb.lab_resource_id = (
            SELECT lab_resource_id FROM lab_batches WHERE id = NEW.lab_batch_id
        ) AND slb.status = 'active') >= (
        SELECT capacity FROM lab_resources WHERE id = (
            SELECT lab_resource_id FROM lab_batches WHERE id = NEW.lab_batch_id
        )) THEN
        RAISE EXCEPTION 'Lab capacity exceeded';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lab_capacity_check 
BEFORE INSERT ON student_lab_batches 
FOR EACH ROW EXECUTE FUNCTION check_lab_capacity();

-- Marks entry authorization
CREATE OR REPLACE FUNCTION check_marks_authorization()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM subject_teachers st
        JOIN exam_subjects es ON st.subject_id = es.subject_id
        WHERE es.id = NEW.exam_subject_id
        AND st.teacher_id = current_setting('app.current_user_id', true)::bigint
    ) THEN
        RAISE EXCEPTION 'Teacher not authorized for this subject';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER marks_authorization_check 
BEFORE INSERT OR UPDATE ON student_marks 
FOR EACH ROW EXECUTE FUNCTION check_marks_authorization();

-- Generic audit trigger
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values)
    VALUES (
        current_setting('app.current_user_id', true)::bigint,
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) ELSE NULL END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to critical tables
CREATE TRIGGER audit_students AFTER INSERT OR UPDATE OR DELETE ON students 
FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_fee_payments AFTER INSERT OR UPDATE OR DELETE ON fee_payments 
FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_student_marks AFTER INSERT OR UPDATE OR DELETE ON student_marks 
FOR EACH ROW EXECUTE FUNCTION audit_trigger();

-- Result completeness validation
CREATE OR REPLACE FUNCTION validate_result_completeness(exam_id BIGINT, student_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN NOT EXISTS (
        SELECT 1 FROM exam_subjects es
        LEFT JOIN student_marks sm ON es.id = sm.exam_subject_id AND sm.student_id = $2
        WHERE es.examination_id = $1 AND sm.id IS NULL
    );
END;
$$ LANGUAGE plpgsql;
```

## INDEXES FOR PERFORMANCE

```sql
-- User and Authentication Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_role_permissions_role_id ON role_permissions(role_id);

-- Student Indexes
CREATE INDEX idx_students_roll_number ON students(roll_number);
CREATE INDEX idx_students_admission_number ON students(admission_number);
CREATE INDEX idx_students_program_id ON students(program_id);
CREATE INDEX idx_students_division_id ON students(division_id);
CREATE INDEX idx_students_status ON students(student_status);
CREATE INDEX idx_students_program_year ON students(program_id, academic_year);
CREATE INDEX idx_students_deleted_at ON students(deleted_at);

-- Fee Management Indexes
CREATE INDEX idx_student_fees_student_id ON student_fees(student_id);
CREATE INDEX idx_student_fees_status ON student_fees(status);
CREATE INDEX idx_fee_payments_student_id ON fee_payments(student_id);
CREATE INDEX idx_fee_payments_payment_date ON fee_payments(payment_date);

-- Academic Indexes
CREATE INDEX idx_subjects_program_year ON subjects(program_id, academic_year);
CREATE INDEX idx_subjects_deleted_at ON subjects(deleted_at);
CREATE INDEX idx_subject_teachers_teacher_id ON subject_teachers(teacher_id);
CREATE INDEX idx_subject_teachers_subject_id ON subject_teachers(subject_id);

-- Attendance Indexes
CREATE INDEX idx_student_attendance_student_id ON student_attendance(student_id);
CREATE INDEX idx_attendance_sessions_date ON attendance_sessions(session_date);

-- Lab Management Indexes
CREATE INDEX idx_student_lab_batches_student_id ON student_lab_batches(student_id);
CREATE INDEX idx_lab_batches_session_id ON lab_batches(lab_session_id);

-- Results Indexes
CREATE INDEX idx_student_marks_student_id ON student_marks(student_id);
CREATE INDEX idx_student_marks_student_subject ON student_marks(student_id, exam_subject_id);
CREATE INDEX idx_student_results_student_id ON student_results(student_id);

-- Audit Indexes
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);

-- Payment Indexes
CREATE INDEX idx_fee_payments_razorpay_id ON fee_payments(razorpay_payment_id);
CREATE INDEX idx_fee_payments_reconciliation ON fee_payments(reconciliation_status);

-- Timetable Indexes
CREATE INDEX idx_timetable_teacher_day ON timetable_slots(teacher_id, day_of_week, academic_year);
CREATE INDEX idx_timetable_division_day ON timetable_slots(division_id, day_of_week, academic_year);

-- JSON Indexes for Performance
CREATE INDEX idx_result_templates_config ON result_templates USING GIN (template_config);
CREATE INDEX idx_saved_reports_filters ON saved_reports USING GIN (filters);
CREATE INDEX idx_permission_groups_permissions ON permission_groups USING GIN (permissions);
```

## SAMPLE DATA STRUCTURE

```json
{
  "department": {
    "id": 1,
    "name": "Commerce",
    "code": "COM",
    "hod_user_id": 15
  },
  "program": {
    "id": 1,
    "name": "Bachelor of Commerce",
    "short_name": "B.Com",
    "code": "BCOM",
    "department_id": 1,
    "duration_years": 3,
    "total_semesters": 6
  },
  "student": {
    "id": 1,
    "roll_number": "2025/FYBCOM/A/001",
    "first_name": "Rahul",
    "last_name": "Sharma",
    "program_id": 1,
    "division_id": 1,
    "student_status": "active"
  },
  "fee_structure": {
    "id": 1,
    "name": "FY B.Com Fees 2025-26",
    "total_amount": 40000,
    "number_of_installments": 2,
    "installments": [
      {
        "installment_number": 1,
        "due_date": "2025-07-15",
        "amount": 25000
      },
      {
        "installment_number": 2,
        "due_date": "2025-12-15",
        "amount": 15000
      }
    ]
  }
}
```

## MIGRATION STRATEGY

1. **Phase 1**: Core tables (Users, Departments, Programs, Students)
2. **Phase 2**: Academic structure (Divisions, Subjects, Enrollments)
3. **Phase 3**: Fee management (Fee structures, Payments)
4. **Phase 4**: Lab management and Attendance
5. **Phase 5**: Results and Library
6. **Phase 6**: HR and Audit systems

This schema supports all your requirements:
- ✅ Hybrid RBAC with department/class/subject isolation
- ✅ Division management (A, B, C divisions)
- ✅ Dynamic fee structures with scholarships
- ✅ Lab batching system
- ✅ Flexible result templates
- ✅ Comprehensive audit trail
- ✅ Scalable for 5000+ students

Ready to start implementation! 🚀