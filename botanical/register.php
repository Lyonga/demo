<?php //include_once('header.php'); ?>
<!Doctype html>
<html lang="en">
<?php
include_once('includes/functions.php');
$user = new User();

    if(isset($_POST['register'])){  
      $UID = $_POST['UID']; 
      $UID1 = $_POST['UID1']; 
      $mail = $_POST['mail'];  
      $pwd = $_POST['pwd'];  
      //$register = $_POST['register'];
      $pwd_repeat = $_POST['pwd_repeat'];  
      if($pwd == $pwd_repeat){  
          $signup = $user->isUserExist($mail);  
          if(!$signup){  
              $signup = $user->UserRegister($UID, $UID1, $mail, $pwd);  
              if($signup){  
                   echo "Registration Successful";  
              }else{  
                  echo "Registration Not Successful>";  
              }  
          } else {  
              echo "Email Already Exist";  
          }  
      } else {  
          echo "Passwords do Not Match";  
        
      }  
  }  
?> 


   <div style="padding-left:50px; padding-top:50px; padding-bottom:50px;">
        <h2>SIGN UP NOW!</h2><br><br>
<form action="" method="POST" name="signup" style="width:600px;border:3px solid black;border-radius:10px;padding:40px 25px;font-size:22px; font-family:Tahoma;">

<div class="form-group">
    <label>Your name</label>
      <input type="name" name="UID" value="" maxlength="50" required="">
</div><br>

    <div class="form-group">
    <label>Your Surname</label>
      <input type="text" name="UID1" value="">
    </div><br>

    <div class="form-group">
    <label>Your email</label>
      <input type="email" name="mail" value="">
    </div><br>

    <div class="form-group">
    <label>Your password</label>
      <input type="password" name="pwd" value="">
    </div><br>

    <div class="form-group">
    <label>Repeat Your password</label>
      <input type="password" name="pwd_repeat" value=""><br>
    </div><br>

      <!--<button type="submit" class="btn btn-primary" name="register" value="signup">Register</button><br><br>-->
      <input type="submit" name="register" value="Signup"/></p><br> 

        <div class="container signin">
            <p>Already have an account? <a href="signin.php">Sign in</a></p>
        </div>

    </form>
</div>
</html>
<style>
    p{
        color:red;
    }
    input {
	display: block;
	box-sizing: border-box;
	width: 100%;
	padding: 8px;
}
    
</style>

<?php //require('includes/footer.php'); ?>