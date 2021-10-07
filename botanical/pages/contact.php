<!Doctype html>
<html lang="en">

<?php include_once('page_header.php'); ?>
<div style="padding-left:300px; padding-top:50px; padding-bottom:50px;">
<h2>Contact Us</h2>
<form style="width:500px;border:3px solid black;border-radius:10px;padding:20px 25px;font-size:30px; font-family:Tahoma;">
      <input type="name" name="first_name" placeholder="Your First name"><br>

      <input type="name" name="second_name" placeholder="Your Second name"><br>

      <input type="email" name="mail" placeholder="Enter Your email"><br>

      <textarea rows="12" cols="65">Message</textarea><br>

      <button type="submit" class="btn btn-success">SEND</button>
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
<?php require('page_footer.php'); ?>