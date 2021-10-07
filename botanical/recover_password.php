<?php 
include('config/DBH.php');

$errors=[];

if (isset($_POST['pass_reset'])) {
  $mail = mysqli_real_escape_string($conn, $_POST['mail']);

  // ensure that the user exists on our system
  $sql = "SELECT * FROM register WHERE reg_mail='$mail'";
  $results = mysqli_query($conn, $sql);
  //$row = mysqli_num_rows($results);

    if (empty($mail)) {
    array_push($errors, "Your email is required");
  }else if(mysqli_num_rows($results) <= 0) {
    array_push($errors, "Sorry, no user exists on our system with that email");
  }
  // generate a unique random token of length 100
  $token = bin2hex(random_bytes(50));

  if (count($errors) == 0) {
          
    // store token in the password-reset database table against the user's email
    $sql = "INSERT INTO password_reset(p_mail, token) VALUES ('$mail', '$token')";
    $results = mysqli_query($conn, $sql);

    // Send email to user with the token in a link they can click on
    $to = $mail;
    $subject = "Reset your password on troicofruitas.com";
    $msg = "Hi there, click on this <a href='http://localhost/tropico-fruitas/new_password.php?token=' . $token . ''>link</a> to reset your password on our site";
    $msg = wordwrap($msg,70);
    $headers = "From: tropicofruitas.com";
    mail($to, $subject, $msg, $headers);
    header('location: pending.php?email=' . $mail);
  }
}

?>

<!Doctype html>
<html lang="en">
<div style="padding-left:300px; padding-top:50px; padding-bottom:50px;">
<h2>PASSWORD RESET!</h2>
<form action="<?php echo htmlspecialchars($_SERVER['PHP_SELF']); ?>" method="POST" style="width:500px;border:3px solid black;border-radius:10px;padding:20px 25px;font-size:22px; font-family:Tahoma;">

    <?php include('includes/messages.php'); ?>
<input type="email" name="mail" placeholder="Your email"><br>


<button type="submit" name="pass_reset" class="btn btn-success">SUBMIT</button><br>

<a href="index.php" class="btn btn-link">Back</a>
</form>
</div>

<style>
input {
	display: block;
	box-sizing: border-box;
	width: 100%;
	padding: 8px;
}
</style>
</html>

<?php //require('includes/footer.php'); ?>