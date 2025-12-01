<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Academic\Division;
use App\Models\Academic\Program;

class DivisionSeeder extends Seeder
{
    public function run(): void
    {
        $programs = Program::all();

        foreach ($programs as $program) {
            // Create academic years for each program
            for ($year = 1; $year <= $program->duration_years; $year++) {
                $yearNames = ['FY', 'SY', 'TY', 'FourthY', 'FifthY'];
                $yearName = $yearNames[$year - 1] ?? "Year{$year}";
                
                $academicYear = \App\Models\Academic\AcademicYear::create([
                    'program_id' => $program->id,
                    'year_number' => $year,
                    'year_name' => $yearName,
                    'semester_start' => ($year - 1) * 2 + 1,
                    'semester_end' => $year * 2,
                    'is_active' => true
                ]);

                // Create divisions A, B, C for each academic year
                Division::create([
                    'division_name' => 'A',
                    'academic_year_id' => $academicYear->id,
                    'max_students' => 60,
                    'is_active' => true
                ]);

                Division::create([
                    'division_name' => 'B',
                    'academic_year_id' => $academicYear->id,
                    'max_students' => 60,
                    'is_active' => true
                ]);
            }
        }
    }
}