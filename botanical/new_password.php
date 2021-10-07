<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<title>Password Reset</title>
	<link rel="stylesheet" href="main.css">
</head>
<?php
include('config/DBH.php');

if (isset($_POST['new_password'])) {
    $new_pass = mysqli_real_escape_string($conn, $_POST['new_pass']);
    $con_new_pass = mysqli_real_escape_string($conn, $_POST['new_pass_c']);
  
    // Grab to token that came from the email link
    $token = $_SESSION['token'];
    if (empty($new_pass) || empty($con_new_pass)) array_push($errors, "Password is required");
    if ($new_pass !== $con_new_pass) array_push($errors, "Password do not match");

    if (count($errors) == 0) {
      // select email address of user from the password_reset table 
      $sql = "SELECT p_mail FROM password_reset WHERE token='$token' LIMIT 1";
      $results = mysqli_query($conn, $sql);
      $mail = mysqli_fetch_assoc($results)['p_mail'];
  
      if ($mail) {
        $hashedpwd = password_hash($new_pass, PASSWORD_DEFAULT);
        //$new_pass = md5($new_pass);

        $sql = "UPDATE register SET reg_pwd='$hashedpwd' WHERE reg_mail='$mail'";
        $results = mysqli_query($conn, $sql);
        header('location: admin/index1.php');
      }
    }
  } 
?>

<body>
	<form class="login-form" action="<?php echo htmlspecialchars($_SERVER['PHP_SELF']); ?>" method="post">
		<h2 class="form-title">New password</h2>
        <?php include('includes/messages.php'); ?>
		<div class="form-group">
			<label>New password</label>
			<input type="password" name="new_pass">
		</div>
		<div class="form-group">
			<label>Confirm new password</label>
			<input type="password" name="con_new_pass">
		</div>
		<div class="form-group">
			<button type="submit" name="new_password" class="login-btn">Submit</button>
		</div>
	</form>

    <style>
    label{
        color:blue;
        font-size:18px;
    }
input {
	display: block;
	box-sizing: border-box;
	width: 100%;
	padding: 8px;
}
</style>
</body>
</html>