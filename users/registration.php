<?php
require_once __DIR__ . '/config.php';

$errors = [];
$success = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $full_name = trim($_POST['full_name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    $confirm_password = $_POST['confirm_password'] ?? '';
    $license = trim($_POST['license_number'] ?? '');
    $phone = trim($_POST['phone_number'] ?? '');
    $address = trim($_POST['address'] ?? '');

    if (empty($full_name) || empty($email) || empty($password) || empty($confirm_password) || empty($license) || empty($phone)) {
        $errors[] = 'Please fill in all required fields.';
    } elseif ($password !== $confirm_password) {
        $errors[] = 'Passwords do not match.';
    } elseif (recordExists($conn, 'user_account', 'email', $email)) {
        $errors[] = 'That email is already registered. Please sign in or use a different email address.';
    } else {
        try {
            $conn->begin_transaction();

            $motorist_id = $conn->insertReturningId(
                "INSERT INTO motorists (full_name, license_number, phone_number, email, address) VALUES (?, ?, ?, ?, ?)",
                [$full_name, $license, $phone, $email, $address]
            );

            $pw_hash = password_hash($password, PASSWORD_DEFAULT);
            $account_id = $conn->insertReturningId(
                "INSERT INTO user_account (full_name, email, password, role, status, motorist_id) VALUES (?, ?, ?, 'user', 'active', ?)",
                [$full_name, $email, $pw_hash, $motorist_id]
            );

            $conn->commit();

            $_SESSION['user_account_id'] = $account_id;
            $_SESSION['user_account_role'] = 'user';
            $_SESSION['user_account_name'] = $full_name;
            $_SESSION['user_account_email'] = $email;
            header('Location: dashboard.php');
            exit();
        } catch (Exception $e) {
            $conn->rollback();
            $errors[] = 'Error creating account: ' . htmlspecialchars($e->getMessage());
        }
    }
}
?>
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Register - <?php echo SITE_NAME; ?></title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body class="bg-light">
<div class="container py-5">
    <div class="row justify-content-center">
        <div class="col-md-6">
            <div class="card shadow-sm">
                <div class="card-body">
                    <h4 class="card-title mb-3">Create an Account</h4>
                    <?php if (!empty($errors)): ?>
                        <div class="alert alert-danger"><ul class="mb-0"><?php foreach($errors as $e) echo '<li>'.htmlspecialchars($e).'</li>'; ?></ul></div>
                    <?php endif; ?>
                    <?php if ($success): ?>
                        <div class="alert alert-success"><?php echo htmlspecialchars($success); ?></div>
                    <?php endif; ?>
                    <form method="POST" action="" autocomplete="off">
                        <div class="mb-3">
                            <label class="form-label">Full name</label>
                            <input type="text" name="full_name" class="form-control" autocomplete="name" placeholder="Enter your full name" value="<?php echo htmlspecialchars($_POST['full_name'] ?? ''); ?>" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Email</label>
                            <input type="email" name="email" class="form-control" autocomplete="email" placeholder="Enter your email address" value="<?php echo htmlspecialchars($_POST['email'] ?? ''); ?>" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Password</label>
                            <input type="password" name="password" class="form-control" autocomplete="new-password" placeholder="Choose a password" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Confirm password</label>
                            <input type="password" name="confirm_password" class="form-control" autocomplete="new-password" placeholder="Confirm your password" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">License number</label>
                            <input type="text" name="license_number" class="form-control" placeholder="Enter your license number" value="<?php echo htmlspecialchars($_POST['license_number'] ?? ''); ?>" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Phone number</label>
                            <input type="text" name="phone_number" class="form-control" placeholder="Enter your phone number" value="<?php echo htmlspecialchars($_POST['phone_number'] ?? ''); ?>" required>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Address</label>
                            <textarea name="address" class="form-control" placeholder="Enter your address"><?php echo htmlspecialchars($_POST['address'] ?? ''); ?></textarea>
                        </div>
                        <button class="btn btn-primary">Register</button>
                    </form>
                    <hr>
                    <a href="login.php">Already have an account? Sign in</a>
                </div>
            </div>
        </div>
    </div>
</div>
</body>
</html>
