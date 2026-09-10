<?php
require_once __DIR__ . '/config.php';

if (isset($_SESSION['user_account_role']) && $_SESSION['user_account_role'] === 'user' && isLoggedIn()) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';

    if (empty($email) || empty($password)) {
        $error = 'Please enter both email and password.';
    } else {
        $user = getUserByEmail($conn, $email);
        if (!$user || !password_verify($password, $user['password'])) {
            $error = 'Invalid email or password.';
        } elseif ($user['status'] !== 'active') {
            $error = 'Your account is not active. Please contact the system administrator.';
        } elseif ($user['role'] === 'admin') {
            $error = 'Admin users must sign in through the admin login page.';
        } else {
            $_SESSION['user_account_id'] = $user['id'];
            $_SESSION['user_account_role'] = $user['role'];
            $_SESSION['user_account_name'] = $user['full_name'];
            $_SESSION['user_account_email'] = $user['email'];
            header('Location: dashboard.php');
            exit;
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>User Login - <?php echo SITE_NAME; ?></title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body class="bg-light">
    <div class="container py-5">
        <div class="row justify-content-center">
            <div class="col-md-5">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h3 class="card-title mb-4">User Login</h3>
                        <?php if (!empty($error)): ?>
                            <div class="alert alert-danger"><?php echo htmlspecialchars($error); ?></div>
                        <?php endif; ?>
                        <form method="POST" action="" autocomplete="off">
                            <div class="mb-3">
                                <label for="email" class="form-label">Email address</label>
                                <input type="email" name="email" id="email" class="form-control" autocomplete="email" placeholder="Enter your email address" value="<?php echo htmlspecialchars($_POST['email'] ?? ''); ?>" required>
                            </div>
                            <div class="mb-3">
                                <label for="password" class="form-label">Password</label>
                                <input type="password" name="password" id="password" class="form-control" autocomplete="current-password" placeholder="Enter your password" required>
                            </div>
                            <button type="submit" class="btn btn-primary w-100">Sign In</button>
                        </form>
                        <div class="mt-3 text-center">
                            <small>Don't have an account? <a href="registration.php">Register here</a>.</small>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
