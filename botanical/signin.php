<?php //include_once('includes/header.php'); ?>
<!Doctype html>
<html lang="en">

<?php  
//session_start();
    include_once('includes/functions.php');
	$user = new User(); 
         
    if(isset($_POST['login_btn'])){  
        $mail = $_POST['mail'];  
        $pwd = $_POST['pwd'];  
        $signin = $user->Login($mail, $pwd);  
        if ($signin) {  
            // Registration Success  
           header("location:admin/index.php");  
        } else {  
            // Registration Failed  
            echo "Email or  Password Not Match";  
        }  
	} 
	?>

<div style="padding-left:300px; padding-top:50px; padding-bottom:50px;">
<h2>SIGN IN NOW!</h2><br><br>
<form action="" method="POST" style="width:300px;border:3px solid black;border-radius:10px;padding:20px 25px;font-size:22px; font-family:Tahoma;">

<input type="email" name="mail" placeholder="Your email" value=""><br>

<input type="password" name="pwd" placeholder="Your password"><br>

<button type="submit" name="login_btn" class="btn btn-success" value="signin">Sign in</button><br><br>

<a class="btn btn-link" href="recover_password.php">forgot your Password</a>
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