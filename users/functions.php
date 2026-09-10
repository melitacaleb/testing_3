<?php
/**
 * users/functions.php - public users area helpers (session keys: user_account_id/user_account_role)
 */

function getUserByEmail($conn, $email)
{
    $stmt = executeQuery($conn, "SELECT * FROM user_account WHERE email = ? LIMIT 1", 's', [$email]);
    return $stmt ? $stmt->fetch_assoc() : null;
}

function getUserReceipts($conn, $user_id)
{
    $stmt = executeQuery($conn, "SELECT * FROM receipts WHERE user_id = ? ORDER BY created_at DESC", 'i', [$user_id]);
    return $stmt ? $stmt->fetch_all() : [];
}

function getUserCitations($conn, $user_id)
{
    $stmt = executeQuery($conn, "SELECT * FROM citations WHERE user_id = ? ORDER BY issued_at DESC", 'i', [$user_id]);
    return $stmt ? $stmt->fetch_all() : [];
}

function getUserComplaints($conn, $user_id)
{
    $stmt = executeQuery($conn, "SELECT * FROM complaints WHERE user_id = ? ORDER BY created_at DESC", 'i', [$user_id]);
    return $stmt ? $stmt->fetch_all() : [];
}

function getCurrentUserId()
{
    return $_SESSION['user_account_id'] ?? null;
}

function isLoggedIn()
{
    return isset($_SESSION['user_account_id'])
        && !empty($_SESSION['user_account_id'])
        && isset($_SESSION['user_account_role'])
        && $_SESSION['user_account_role'] === 'user';
}

function isAdmin()
{
    return false;
}

function requireLogin()
{
    if (!isLoggedIn()) {
        header('Location: login.php');
        exit();
    }
}
