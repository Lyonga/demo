<?php  
require_once 'config/config.php';  
//session_start();  
class User{
	public $conn;
	public function __construct(){
		$this->conn = new mysqli(DBHOST, DBUSER, DBPASS, DBNAME);

		if(mysqli_connect_errno()) {
			echo "Error: Could not connect to database.";
		 exit;
		}
    }
    
        public function UserRegister($UID, $UID1, $mail, $pwd){  
                $pwd = md5($pwd);
                $result = mysqli_query($this->conn,"INSERT INTO users(r_name, r_surname, r_email, r_pwd) values('$UID', '$UID1', '$mail', '$pwd')") or die(mysql_error());  
                return $result;  
               
        }  
        public function Login($mail, $pwd){  
            $pwd = md5($pwd);
            $result = mysqli_query($this->conn, "SELECT * FROM users WHERE r_email = '$mail' AND r_pwd = '$pwd'");  
            $user_data = mysqli_fetch_array($result);  
            //print_r($user_data);  
            $no_rows = mysqli_num_rows($result);  
              
            if ($no_rows == 1)   
            {  
           //session_start();
                $_SESSION['login'] = true;  
                $_SESSION['uid'] = $user_data['r_id'];  
                $_SESSION['name'] = $user_data['r_name'];
                $_SESSION['username'] = $user_data['r_surname'];
                $_SESSION['email'] = $user_data['r_email'];  
                return true;  
            }  
            else  
            {  
                return FALSE;  
            }  
               
                   
        }  
        public function isUserExist($mail){  
            //$sql = mysql_query("SELECT * FROM users WHERE r_email = '".$mail."'"); 
            $sql = "SELECT * FROM users WHERE r_email = '".$mail."'"; 
            $check =  $this->conn->query($sql) ;
            $count_row = $check->num_rows;
  
            if($count_row > 0){  
                return true;  
            } else {  
                return false;  
            }  
        } 
        
        /*** starting the session ***/
        public function get_session(){
            return $_SESSION['login'];
        }

        //logout function
        public function user_logout() {
            $_SESSION['login'] = FALSE;
            session_destroy();
        }
    }  
?>  