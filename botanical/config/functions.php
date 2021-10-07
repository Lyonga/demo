<?php
include('../config/config.php');

//ceate blog function
public function CreateBlog($title, $body, $author){  
    $result = mysqli_query($this->conn, "INSERT INTO blog(b_title, b_body, b_author) values('$title', '$body', '$body')"); 
    return $result; 
}

//fetch all blogs Function
public function FetchBlog(){
	$result = mysqli_query($this->conn, "SELECT * FROM blog");
	return $result;
    }
    
    //view one Function
public function FetchOneRecord($view_id){
$oneresult = mysqli_query($this->conn,"SELECT * FROM blog WHERE b_id = $view_id");
return $oneresult;
}

//update blog function
public function UpdateBlog($title, $body, $author){
	$updaterecord = mysqli_query($this->conn, "UPDATE blog SET b_title='$title', b_body='$body', b_author='$author' WHERE b_id = '$update_id' ");
	return $updaterecord;
    }
    
    //delete blog Function
public function DeleteBlog($delete_id){
$deleterecord = mysqli_query($this->conn, "DELETE FROM blog WHERE b_id = $delete_id");
return $deleterecord;
}

//ARTICLE FUNCTIONS

//ceate article function
public function CreateArticle($title, $body, $author){  
    $result = mysqli_query($this->conn, "INSERT INTO article(a_title, a_body, a_author) values('$title', '$body', '$body')"); 
    return $result; 
}

//fetch all articles Function
public function FetchArticles(){
	$result = mysqli_query($this->conn, "SELECT * FROM article");
	return $result;
    }
    
    //view one article Function
public function FetchOneArticle($view_id){
$oneresult = mysqli_query($this->conn,"SELECT * FROM article WHERE a_id=$view_id");
return $oneresult;
}

//update article function
public function UpdateArticle($title, $body, $author){
	$updaterecord = mysqli_query($this->conn, "UPDATE article SET a_title='$title', a_body='$body', a_author='$author' WHERE a_id='$update_id' ");
	return $updaterecord;
    }
    
    //delete article Function
public function DeleteArticle($delete_id){
$deleterecord = mysqli_query($this->conn, "DELETE FROM article WHERE a_id=$delete_id");
return $deleterecord;
}
?>