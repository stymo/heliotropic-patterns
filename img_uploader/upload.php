<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">
    <title>Heliotropic Patterns - Image Upload</title>
<script>
  // CLIENT SIDE VALIDATION - JS
  function validateFile() {
      const fileInput = document.getElementById('fileToUpload');
      const filePath = fileInput.value;
      const allowedExtensions = /(\.jpg|\.jpeg)$/i;

      if (!allowedExtensions.exec(filePath)) {
        alert('Please upload a jpeg file.');
        fileInput.value = '';
        return false;
      }
      
      // File type is valid, proceed with form submission and other actions
      document.getElementById('uploadSpinner').setAttribute('style', 'display:block');
      document.getElementById('uploadForm').submit();
  }
</script>  
</head>
<body>
    <div class="container">
    <h2 class="mt-3 mb-1">Feed me sunshine!</h2> 
<?php
// SERVER SIDE PROCESSING - PHP
$error = false;
$successMessage = '';
$errorMessage = '';
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST["submit"])) {
    if (isset($_FILES["fileToUpload"]) && $_FILES["fileToUpload"]["error"] == UPLOAD_ERR_OK) {
        $uploadDir = "heliotropic_img_uploads"; 
        $uploadFile = pathinfo($_FILES["fileToUpload"]["name"], PATHINFO_BASENAME);
        $uploadFile = pathinfo($uploadFile, PATHINFO_FILENAME);
        $uploadFile = uniqid($uploadFile . '_');
        $uploadFile = $uploadDir . "/" . $uploadFile . ".jpg";

        // Move uploaded file to designated directory
        if (move_uploaded_file($_FILES["fileToUpload"]["tmp_name"], $uploadFile)) {
            $successMessage =  "The file ". basename($_FILES["fileToUpload"]["name"]). " has been uploaded. <br/>Feel free to upload another!";
        } else {
            echo "Sorry, there was an error uploading your file. Please find Sam.";
        }
    } else {
        echo "Please choose a file, then press the Upload File button. <br/> If you need further help, please find Sam.";
    }
} 
?>
<!-- Display success or error messages -->
<?php if ($error): ?>
  <div class="message error"><?php echo $errorMessage; ?></div>
<?php elseif (!empty($successMessage)): ?>
  <div class="message success"><?php echo $successMessage; ?></div>
<?php endif; ?>
<div class="spinner-border" role="status" id="uploadSpinner" style="display:none"> </div>
  <form id="uploadForm" name="uploadForm" action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]); ?>" method="post" enctype="multipart/form-data">
        <div class="mb-3">
          <!-- <label for="fileUpload" class="form-label">Choose a file to upload:</label> -->
          <input type="file" class="form-control mt-3" id="fileToUpload" name="fileToUpload" accept="image/jpg, image/jpeg">
        </div>
        <button type="submit" name="submit" onclick="validateFile()" class="btn btn-primary mb-3">Upload File</button>
    </form>
    </div> 
</body>
</html>
