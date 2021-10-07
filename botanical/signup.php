<?php include_once('includes/header.php'); ?>
<!Doctype html>
<html lang="en">


<?php
  if(isset($_GET['error'])){
      if($_GET['error'] == "emptyfields"){
          echo '<p class="signuperror">Fill in all Fields</p>';
      }
      elseif($_GET['error'] == "invalidmail"){
        echo '<p class="signuperror">please fill in a proper email</p>';
      }
      elseif($_GET['error'] == "passwordcheck"){
        echo '<p class="signuperror">please passwords do not match Retry</p>';
      }
      elseif($_GET['error'] == "userNametaken"){
        echo '<p class="signuperror">UserName is taken choose a new one</p>';
      }

  }
  if(isset($_GET['signin'])){
  if($_GET['signup'] == "successful"){
    echo '<p class="signupsuccess">You have sucessfully signed up!!</p>';
  }
  }
?>
   <div style="padding-left:50px; padding-top:50px; padding-bottom:50px;">
        <h2>SIGN UP NOW!</h2><br><br>
<form action="includes/register.php" method="POST" style="width:600px;border:3px solid black;border-radius:10px;padding:40px 25px;font-size:22px; font-family:Tahoma;">

      <input type="name" name="UID" placeholder="Your name" value="" maxlength="50" required=""><br>

      <input type="text" name="UID1" placeholder="Your user name" value=""><br>

      <input type="email" name="mail" placeholder="Your email" value=""><br>

      <input type="password" name="pwd" placeholder="Your password" value=""><br>

      <input type="password" name="pwd_repeat" placeholder="Repeat Your password" value=""><br>

      <input type="gender" name="sex" placeholder="Your gender" value=""><br>

      <button type="submit" class="btn btn-primary" name="register_btn">Register</button><br><br>

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