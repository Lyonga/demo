<?php include_once('page_header.php'); ?>
<!Doctype html>
<html lang="en">
<div style="padding-left:300px; padding-top:50px; padding-bottom:50px;">
<h2>REGISTER NOW!</h2>
     <form action="register.php" method="POST" style="width:300px;border:3px solid black;border-radius:10px;padding:20px 25px;font-size:22px; font-family:Tahoma;">
    
      <input type="text" name="first_name" placeholder="Your First name"><br>

      <input type="text" name="second_name" placeholder="Your Second name"><br>

      <input type="email" name="mail" placeholder="Your email"><br>

      <input type="password" name="pwd" placeholder="Your password"><br>

      <input type="password" name="pwd" placeholder="Repeat Your password"><br>

      <input type="gender" name="sex" placeholder="Your gender"><br>

      <input type="age" name="age" placeholder="Your age"><br>

      Agree to Terms of Service<br>
      <input type="checkbox" name="agree"><br>

      <input type="hidden" name="form_submitted" value="1">

      <button type="submit" class="btn btn-success">Register</button>

        <div class="container signin">
            <p>Already have an account? <a href="sign in.php">Sign in</a>.</p>
        </div>

    </form>
</div>
</html>

<?php require('page_footer.php'); ?>