# CLIENT REQUIREMENTS - MR. ROHIT

## PROJECT OVERVIEW
Build an ERP/CRM system for educational organizations (Schools, Junior Colleges, Degree Colleges) primarily for the Indian education system.

## KEY REQUIREMENTS CONFIRMED

### CORE FEATURES (MVP Phase 1)
- **Data Isolation**: Hybrid RBAC (Department + Class + Subject based access)
- **Division Management**: A, B, C divisions with proper student assignment
- **Lab Batching**: Dynamic batching (100 students → 5 batches) with manual assignment
- **Dynamic Fee Management**: Configurable structures, scholarships, installments
- **Flexible Subject Codes**: Admin has complete control (any university pattern)
- **Result Templates**: Configurable marksheet generation (Marks + CGPA systems)
- **Dynamic Reporting**: Customizable reports with drag-drop columns
- **Online Payment Gateway**: Razorpay integration
- **Student/Parent Portal**: Login access for JC/Degree students
- **Library Module**: Book management, issue/return
- **HR/Payroll Module**: Staff management, salary processing

### MODULES NOT NEEDED (Phase 1)
- ❌ Transport Module
- ❌ Hostel Module  
- ❌ WhatsApp Integration
- ❌ Mobile App
- ❌ Multi-language Support
- ❌ Government Portal Integration
- ❌ Learning Plan (Phase 2)
- ❌ Biometric Attendance (Phase 2)

### PROGRAMS SUPPORTED
- **Commerce**: B.Com, M.Com, BBA
- **Science**: B.Sc CS, B.Sc Cyber Security, B.Sc Animation, M.Sc CS, M.Sc Data Science
- **Management**: MBA
- **Arts**: BA

### ACCESS CONTROL CONFIRMED
- **Class Teacher**: Sees only assigned division students (all subjects)
- **Subject Teacher**: Sees all students taking their subject (subject-specific data only)
- **HOD**: Sees all department students + can assign permissions to teachers
- **Principal**: Full access to everything

### TECHNICAL DECISIONS
- **Timeline**: ASAP for testing before new academic year
- **Development**: GitHub Codespaces + Amazon Q
- **Tech Stack**: Laravel + React + PostgreSQL + Redis
- **Budget**: Develop MVP first, then decide
- **Subject Codes**: Admin has sole authority (supports any university pattern)
- **Grading**: Both Marks and CGPA systems (admin configurable)

### SCALE REQUIREMENTS
- **Students**: 5000+ per institution
- **Staff**: 100+ concurrent users
- **Performance**: <2 second page loads
- **Reliability**: 99.9% uptime target

## IMPLEMENTATION STATUS
✅ **Architecture Complete**: System design finalized  
✅ **Database Schema**: 50+ tables designed  
✅ **Roadmap Ready**: 12-week implementation plan  
🚀 **Next Step**: Begin Laravel + React development