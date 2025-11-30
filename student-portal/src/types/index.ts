export interface User {
  id: number;
  name: string;
  email: string;
  role: string;
}

export interface Student {
  id: number;
  roll_number: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  date_of_birth: string;
  gender: string;
  admission_date: string;
  status: string;
  division: Division;
  program: Program;
}

export interface Division {
  id: number;
  name: string;
  capacity: number;
  current_strength: number;
}

export interface Program {
  id: number;
  name: string;
  code: string;
  duration_years: number;
  degree_type: string;
}

export interface AttendanceRecord {
  id: number;
  attendance_date: string;
  status: string;
  check_in_time?: string;
  remarks?: string;
}

export interface FeeRecord {
  id: number;
  total_amount: number;
  paid_amount: number;
  outstanding_amount: number;
  status: string;
  due_date: string;
}

export interface MarkRecord {
  id: number;
  subject: Subject;
  marks_obtained: number;
  total_marks: number;
  percentage: number;
  grade: string;
  status: string;
}

export interface Subject {
  id: number;
  name: string;
  code: string;
  credits: number;
}

export interface Timetable {
  id: number;
  subject: Subject;
  day_of_week: string;
  start_time: string;
  end_time: string;
  room: string;
  teacher: string;
}