<?php
require_once __DIR__ . '/config.php';
requireLogin();

if (isAdmin()) {
    header('Location: ../admin/index.php');
    exit();
}

$user_id = getCurrentUserId();
$user = getRecordById($conn, 'user_account', $user_id);
$errors = [];
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $full_name = trim($_POST['full_name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';

    if (empty($full_name)) {
        $errors[] = 'Full name is required.';
    }
    if (empty($email)) {
        $errors[] = 'Email is required.';
    }
    if (recordExists($conn, 'user_account', 'email', $email, $user_id)) {
        $errors[] = 'That email is already in use by another account.';
    }

    if (empty($errors)) {
        $sql = "UPDATE user_account SET full_name = ?, email = ?";
        $params = [$full_name, $email];

        if (!empty($password)) {
            $sql .= ", password = ?";
            $params[] = password_hash($password, PASSWORD_DEFAULT);
        }

        $sql .= " WHERE id = ?";
        $params[] = $user_id;

        $stmt = executeQuery($conn, $sql, '', $params);
        if ($stmt) {
            $message = 'Profile updated successfully.';
            $_SESSION['user_account_name'] = $full_name;
            $_SESSION['user_account_email'] = $email;
            $user = getRecordById($conn, 'user_account', $user_id);
        } else {
            $errors[] = 'Unable to update profile. Please try again.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Edit Profile - <?php echo SITE_NAME; ?></title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body class="bg-light">
    <div class="container py-5">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h1 class="h3">Edit Profile</h1>
                <p class="text-muted">Change your name, email, or password.</p>
            </div>
            <div>
                <a href="profile.php" class="btn btn-secondary me-2">Back to Profile</a>
                <a href="logout.php" class="btn btn-danger">Logout</a>
            </div>
        </div>

        <?php if (!empty($errors)): ?>
            <div class="alert alert-danger">
                <ul class="mb-0">
                    <?php foreach ($errors as $error): ?>
                        <li><?php echo htmlspecialchars($error); ?></li>
                    <?php endforeach; ?>
                </ul>
            </div>
        <?php endif; ?>

        <?php if (!empty($message)): ?>
            <div class="alert alert-success"><?php echo htmlspecialchars($message); ?></div>
        <?php endif; ?>

        <div class="card shadow-sm">
            <div class="card-body">
                <form method="POST" action="">
                    <div class="mb-3">
                        <label class="form-label" for="full_name">Full Name</label>
                        <input type="text" name="full_name" id="full_name" class="form-control" value="<?php echo htmlspecialchars($user['full_name']); ?>" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="email">Email</label>
                        <input type="email" name="email" id="email" class="form-control" value="<?php echo htmlspecialchars($user['email']); ?>" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="password">New Password <small class="text-muted">(leave blank to keep the same)</small></label>
                        <input type="password" name="password" id="password" class="form-control">
                    </div>
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                </form>
            </div>
        </div>
    </div>
</body>
</html>
