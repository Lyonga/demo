<!Doctype html>
<html lang="en">
<head>
  <title>UPDATE-ARTICLE</title>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>
<?php 
include_once('includes/functions.php');
//get particular id to fetch
$update_id =  trim($_GET["update_id"]);

$user = new user();
$sql = $user->FetchOneArticle($update_id);
$cnt = 1;
while($row = mysqli_fetch_array($sql))
  {
    $title = $row["a_title"];
    $body = $row["a_body"];
    $author = $row["a_author"];
?>

<body style="padding-left:120px">
<?php echo "<a href='all_blogs.php' class='btn btn-info m-r-1em'>BACK TO ALL BLOGPOSTS</a>";?>
    <h2>UPDATE  ARTICLE</h2>
    <form method="POST" action="">
        <input type="hidden" name="update_id" value="<?php echo $_GET["update_id"]; ?>"><br>
        <input type="text" name="title" placeholder="Enter Blog Title" value="<?php echo $title;?>"><br><br>

        <textarea rows="20" cols="95" name="body" placeholder="Blog Body HERE"><?php echo $body;?></textarea><br><br>

        <input type="text" name="author" placeholder="Enter Blog Author" value="<?php echo $author;?>"><br><br>

        <?php } ?>

        <button type="submit" class="btn btn-primary" name="update">Update Article</button>
    </form>


<?php 
//include_once('includes/functions.php');

$user = new user();

//get particular id to fetch
if(isset($_POST['update_id'])){
  $update_id =  trim($_POST["update_id"]);

$title = $_POST['title'];
$body = $_POST['body'];
$author = $_POST['author'];
$sql = $user->UpdateArticle($title, $body, $author, $update_id);
if($sql){
echo "Article Updated successfull";
header("location:all_articles.php");
}else{
  echo "something went wrong";
}
}
?>
</body>
</html>