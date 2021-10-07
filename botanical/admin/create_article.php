<!Doctype html>
<html lang="en">
<head>
  <title>INSERT-NEW-ARTICLE</title>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>

<?php
//include_once("b_header.php");
include_once('includes/functions.php');

$user = new user();
if(isset($_POST['insert'])){

    $title = $_POST['title'];
    $body = $_POST['body'];
    $author = $_POST['author'];

    $sql = $user->CreateArticle($title, $body, $author);
    if($sql){
        echo "Article created successfully";
        header('Location:all_articles.php');
    }else{
        echo "something went wrong, contact admin";
    }
}
?>
<body style="padding-left:120px">
<?php echo "<a href='all_blogs.php' class='btn btn-info m-r-1em'>BACK TO ALL BLOGPOSTS</a>";?>
    <h2>CREATE NEW  ARTICLE</h2>
    <form method="POST" action="">
        <input type="text" name="title" placeholder="Enter Blog Title" value=""><br><br>

        <textarea rows="20" cols="95" name="body" placeholder="Blog Body HERE"></textarea><br><br>

        <input type="text" name="author" placeholder="Enter Blog Author" value=""><br><br>

        <button type="submit" class="btn btn-primary" name="insert">Create Article</button>
    </form>
</body>
</html>