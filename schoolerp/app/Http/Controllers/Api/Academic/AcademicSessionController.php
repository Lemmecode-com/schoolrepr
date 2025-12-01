<?php

namespace App\Http\Controllers\Api\Academic;

use App\Http\Controllers\Controller;
use App\Models\Academic\AcademicSession;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AcademicSessionController extends Controller
{
    public function index(): JsonResponse
    {
        $sessions = AcademicSession::orderBy('start_date', 'desc')->get();
        
        return response()->json([
            'success' => true,
            'data' => $sessions
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
            'is_active' => 'boolean'
        ]);

        $session = AcademicSession::create($request->all());

        return response()->json([
            'success' => true,
            'message' => 'Academic session created successfully',
            'data' => $session
        ], 201);
    }

    public function show(AcademicSession $academicSession): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $academicSession
        ]);
    }

    public function update(Request $request, AcademicSession $academicSession): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
            'is_active' => 'boolean'
        ]);

        $academicSession->update($request->all());

        return response()->json([
            'success' => true,
            'message' => 'Academic session updated successfully',
            'data' => $academicSession
        ]);
    }

    public function destroy(AcademicSession $academicSession): JsonResponse
    {
        $academicSession->delete();

        return response()->json([
            'success' => true,
            'message' => 'Academic session deleted successfully'
        ]);
    }
}