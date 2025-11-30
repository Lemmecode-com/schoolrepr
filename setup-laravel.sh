#!/bin/bash

# Educational ERP System - Laravel Setup Script
# Run this in GitHub Codespaces

echo "🚀 Setting up Educational ERP System..."

# 1. Create Laravel Project
echo "📦 Creating Laravel project..."
composer create-project laravel/laravel schoolerp --prefer-dist
cd schoolerp

# 2. Install Required Packages
echo "📚 Installing required packages..."
composer require laravel/sanctum
composer require spatie/laravel-permission
composer require barryvdh/laravel-dompdf
composer require predis/predis
composer require razorpay/razorpay
composer require maatwebsite/excel

# 3. Install Development Packages
composer require --dev laravel/telescope
composer require --dev barryvdh/laravel-debugbar

# 4. Configure Environment
echo "⚙️ Configuring environment..."
cp .env.example .env

# Update .env file with PostgreSQL configuration
cat >> .env << EOL

# Database Configuration
DB_CONNECTION=pgsql
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=schoolerp
DB_USERNAME=postgres
DB_PASSWORD=password

# Redis Configuration
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# Queue Configuration
QUEUE_CONNECTION=redis

# Session Configuration
SESSION_DRIVER=redis
SESSION_LIFETIME=120

# Cache Configuration
CACHE_DRIVER=redis

# Razorpay Configuration
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret

# Mail Configuration (for notifications)
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=your_email@gmail.com
MAIL_FROM_NAME="School ERP System"
EOL

# 5. Generate Application Key
php artisan key:generate

# 6. Publish Sanctum Configuration
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"

# 7. Publish Spatie Permission Configuration
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider"

# 8. Create Database Migrations Directory Structure
echo "📁 Creating migration structure..."
mkdir -p database/migrations/2024_01_01_000000_create_core_tables
mkdir -p database/migrations/2024_01_02_000000_create_academic_tables
mkdir -p database/migrations/2024_01_03_000000_create_fee_tables
mkdir -p database/migrations/2024_01_04_000000_create_lab_tables
mkdir -p database/migrations/2024_01_05_000000_create_result_tables

# 9. Create Models Directory Structure
echo "📂 Creating model structure..."
mkdir -p app/Models/Academic
mkdir -p app/Models/Fee
mkdir -p app/Models/Lab
mkdir -p app/Models/Result
mkdir -p app/Models/User

# 10. Create Controllers Directory Structure
echo "🎮 Creating controller structure..."
mkdir -p app/Http/Controllers/Api/Academic
mkdir -p app/Http/Controllers/Api/Fee
mkdir -p app/Http/Controllers/Api/Lab
mkdir -p app/Http/Controllers/Api/Result
mkdir -p app/Http/Controllers/Api/Report

# 11. Create Services Directory
echo "🔧 Creating services..."
mkdir -p app/Services
mkdir -p app/Services/Fee
mkdir -p app/Services/Academic
mkdir -p app/Services/Report

# 12. Create Middleware
echo "🛡️ Creating middleware..."
php artisan make:middleware CheckPermission
php artisan make:middleware SetCurrentUser
php artisan make:middleware CheckDivisionAccess

# 13. Create Basic Seeders
echo "🌱 Creating seeders..."
php artisan make:seeder RolePermissionSeeder
php artisan make:seeder DepartmentSeeder
php artisan make:seeder ProgramSeeder
php artisan make:seeder UserSeeder

# 14. Create Basic Models
echo "🏗️ Creating core models..."
php artisan make:model Models/Academic/Department
php artisan make:model Models/Academic/Program
php artisan make:model Models/Academic/Division
php artisan make:model Models/Academic/Subject
php artisan make:model Models/User/Student
php artisan make:model Models/User/StaffProfile
php artisan make:model Models/Fee/FeeStructure
php artisan make:model Models/Fee/FeePayment

# 15. Create API Controllers
echo "🌐 Creating API controllers..."
php artisan make:controller Api/AuthController
php artisan make:controller Api/Academic/StudentController --api
php artisan make:controller Api/Academic/DivisionController --api
php artisan make:controller Api/Fee/FeeController --api
php artisan make:controller Api/Report/ReportController --api

# 16. Create Services
echo "⚙️ Creating services..."
cat > app/Services/RollNumberService.php << 'EOL'
<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class RollNumberService
{
    public static function generate($programId, $academicYear, $divisionName)
    {
        return DB::transaction(function() use ($programId, $academicYear, $divisionName) {
            $sequence = DB::table('roll_number_sequences')
                ->where([
                    'program_id' => $programId, 
                    'academic_year' => $academicYear, 
                    'division_name' => $divisionName
                ])
                ->lockForUpdate()
                ->first();
            
            $nextNumber = $sequence ? $sequence->last_number + 1 : 1;
            
            DB::table('roll_number_sequences')->updateOrInsert(
                [
                    'program_id' => $programId, 
                    'academic_year' => $academicYear, 
                    'division_name' => $divisionName
                ],
                ['last_number' => $nextNumber]
            );
            
            // Get program code
            $program = DB::table('programs')->where('id', $programId)->first();
            
            return sprintf('%s/%s/%s/%03d', 
                $academicYear, 
                $program->code, 
                $divisionName, 
                $nextNumber
            );
        });
    }
}
EOL

# 17. Create Fee Calculation Service
cat > app/Services/Fee/FeeCalculationService.php << 'EOL'
<?php

namespace App\Services\Fee;

use App\Models\Fee\FeeStructure;
use App\Models\Fee\StudentScholarship;

class FeeCalculationService
{
    public static function calculateStudentFee($studentId, $feeStructureId)
    {
        $structure = FeeStructure::find($feeStructureId);
        $scholarships = StudentScholarship::where('student_id', $studentId)
            ->where('approval_status', 'approved')
            ->get();
        
        $totalAmount = $structure->total_amount;
        
        foreach($scholarships as $scholarship) {
            $totalAmount -= $scholarship->discount_amount;
        }
        
        return max(0, $totalAmount); // Never negative
    }
    
    public static function calculateInstallments($feeStructureId, $totalAmount)
    {
        $installments = DB::table('installments')
            ->where('fee_structure_id', $feeStructureId)
            ->orderBy('installment_number')
            ->get();
        
        $result = [];
        foreach($installments as $installment) {
            $result[] = [
                'installment_number' => $installment->installment_number,
                'due_date' => $installment->due_date,
                'amount' => $installment->amount,
                'status' => 'pending'
            ];
        }
        
        return $result;
    }
}
EOL

# 18. Create Basic API Routes
cat > routes/api.php << 'EOL'
<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\Academic\StudentController;
use App\Http\Controllers\Api\Academic\DivisionController;
use App\Http\Controllers\Api\Fee\FeeController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Authentication Routes
Route::post('/login', [AuthController::class, 'login']);
Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
Route::get('/user', [AuthController::class, 'user'])->middleware('auth:sanctum');

// Protected Routes
Route::middleware(['auth:sanctum'])->group(function () {
    
    // Student Management
    Route::apiResource('students', StudentController::class);
    Route::get('students/{student}/profile', [StudentController::class, 'profile']);
    
    // Division Management
    Route::apiResource('divisions', DivisionController::class);
    Route::get('divisions/{division}/students', [DivisionController::class, 'students']);
    
    // Fee Management
    Route::apiResource('fees', FeeController::class);
    Route::post('fees/{student}/payment', [FeeController::class, 'recordPayment']);
    Route::get('fees/{student}/outstanding', [FeeController::class, 'outstanding']);
    
});

// Webhook Routes (no authentication)
Route::post('/webhooks/razorpay', [FeeController::class, 'razorpayWebhook']);
EOL

# 19. Update Kernel.php with custom middleware
echo "🔧 Configuring middleware..."

# 20. Create basic configuration files
cat > config/schoolerp.php << 'EOL'
<?php

return [
    
    /*
    |--------------------------------------------------------------------------
    | School ERP Configuration
    |--------------------------------------------------------------------------
    */
    
    'academic_year' => [
        'current' => '2025-26',
        'format' => 'Y-y', // 2025-26 format
    ],
    
    'roll_number' => [
        'format' => '{academic_year}/{program_code}/{division}/{number}',
        'padding' => 3, // 001, 002, etc.
    ],
    
    'fee' => [
        'currency' => 'INR',
        'decimal_places' => 2,
        'late_fee_grace_days' => 7,
    ],
    
    'attendance' => [
        'minimum_percentage' => 75,
        'grace_percentage' => 5,
    ],
    
    'results' => [
        'pass_percentage' => 40,
        'grace_marks' => 5,
    ],
    
    'pagination' => [
        'per_page' => 25,
        'max_per_page' => 100,
    ],
    
];
EOL

echo "✅ Laravel setup complete!"
echo ""
echo "Next steps:"
echo "1. Start PostgreSQL and Redis services"
echo "2. Create database: createdb schoolerp"
echo "3. Run migrations: php artisan migrate"
echo "4. Seed initial data: php artisan db:seed"
echo "5. Start development server: php artisan serve"
echo ""
echo "🎯 Ready to begin Phase 1A development!"