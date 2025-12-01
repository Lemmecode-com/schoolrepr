<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Academic\Program;
use App\Models\Academic\Department;

class ProgramSeeder extends Seeder
{
    public function run(): void
    {
        $commerceDept = Department::where('code', 'COM')->first();
        $scienceDept = Department::where('code', 'SCI')->first();
        $artsDept = Department::where('code', 'ARTS')->first();

        if ($commerceDept) {
            Program::create([
                'name' => 'Bachelor of Commerce',
                'short_name' => 'B.Com',
                'code' => 'BCOM',
                'department_id' => $commerceDept->id,
                'duration_years' => 3,
                'total_semesters' => 6,
                'program_type' => 'undergraduate',
                'is_active' => true
            ]);

            Program::create([
                'name' => 'Master of Commerce',
                'short_name' => 'M.Com',
                'code' => 'MCOM',
                'department_id' => $commerceDept->id,
                'duration_years' => 2,
                'total_semesters' => 4,
                'program_type' => 'postgraduate',
                'is_active' => true
            ]);

            Program::create([
                'name' => 'Bachelor of Business Administration',
                'short_name' => 'BBA',
                'code' => 'BBA',
                'department_id' => $commerceDept->id,
                'duration_years' => 3,
                'total_semesters' => 6,
                'program_type' => 'undergraduate',
                'is_active' => true
            ]);
        }

        if ($scienceDept) {
            Program::create([
                'name' => 'Bachelor of Science in Computer Science',
                'short_name' => 'B.Sc CS',
                'code' => 'BSCCS',
                'department_id' => $scienceDept->id,
                'duration_years' => 3,
                'total_semesters' => 6,
                'program_type' => 'undergraduate',
                'is_active' => true
            ]);

            Program::create([
                'name' => 'Bachelor of Science in Information Technology',
                'short_name' => 'B.Sc IT',
                'code' => 'BSCIT',
                'department_id' => $scienceDept->id,
                'duration_years' => 3,
                'total_semesters' => 6,
                'program_type' => 'undergraduate',
                'is_active' => true
            ]);
        }

        if ($artsDept) {
            Program::create([
                'name' => 'Bachelor of Arts',
                'short_name' => 'BA',
                'code' => 'BA',
                'department_id' => $artsDept->id,
                'duration_years' => 3,
                'total_semesters' => 6,
                'program_type' => 'undergraduate',
                'is_active' => true
            ]);
        }
    }
}