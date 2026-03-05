

https://medium.com/@tradingcontentdrive/deploying-a-flask-file-upload-app-with-amazon-efs-on-ec2-374e313539d4

app.py

`
from flask import Flask, request, render_template_string, send_from_directory, jsonify
from werkzeug.utils import secure_filename
import os

app = Flask(__name__)

UPLOAD_FOLDER = "/mnt/efs/uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ---------------- HTML TEMPLATE ----------------
html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>EFS File Upload Portal</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
  <style>
    body {
      margin: 0;
      font-family: 'Poppins', sans-serif;
      background: linear-gradient(135deg, #007bff, #00bcd4, #4caf50);
      background-size: 400% 400%;
      animation: gradientFlow 10s ease infinite;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      color: #333;
    }
    @keyframes gradientFlow {
      0% { background-position: 0% 50%; }
      50% { background-position: 100% 50%; }
      100% { background-position: 0% 50%; }
    }
    .container {
      background: #ffffffcc;
      backdrop-filter: blur(6px);
      border-radius: 18px;
      padding: 40px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.15);
      width: 90%;
      max-width: 800px;
      animation: fadeIn 1s ease;
    }
    h1 {
      text-align: center;
      color: #0056b3;
      font-weight: 600;
      margin-bottom: 20px;
    }
    .upload-area {
      border: 2px dashed #0d6efd;
      border-radius: 12px;
      padding: 40px 20px;
      background: #f9fbff;
      transition: all 0.3s ease;
      text-align: center;
    }
    .upload-area:hover {
      background: #e8f0fe;
      box-shadow: 0 0 10px rgba(13, 110, 253, 0.3);
      transform: translateY(-2px);
    }
    input[type=file] {
      display: block;
      margin: 10px auto;
      width: 80%;
    }
    .btn {
      padding: 10px 25px;
      border-radius: 8px;
      font-weight: 500;
      transition: all 0.3s;
    }
    .btn:hover { transform: scale(1.05); }
    .progress { height: 25px; margin-top: 15px; display: none; }
    .progress-bar { transition: width 0.4s ease; font-weight: 500; }
    .file-card {
      background: linear-gradient(135deg, #ffffff, #f2f7ff);
      padding: 10px 15px;
      border-radius: 10px;
      margin: 5px 0;
      display: flex;
      align-items: center;
      justify-content: space-between;
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .file-card:hover {
      transform: translateY(-3px);
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    }
    .file-icon { color: #0d6efd; font-size: 1.4em; margin-right: 10px; }
    .footer { text-align: center; margin-top: 20px; font-size: 14px; color: #666; }
    @keyframes fadeIn { from {opacity:0;transform:translateY(20px);} to {opacity:1;transform:translateY(0);} }
  </style>
</head>
<body>
  <div class="container">
    <h1><i class="bi bi-cloud-upload"></i> Amazon EFS File Manager</h1>
    <div class="upload-area">
      <p class="mb-3 text-muted">Select a file to upload to your shared EFS storage</p>
      <input id="fileInput" type="file" name="file" required>
      <button id="uploadBtn" class="btn btn-primary mt-2"><i class="bi bi-upload"></i> Upload</button>
      <div class="progress mt-3">
        <div id="progressBar" class="progress-bar progress-bar-striped progress-bar-animated bg-success" role="progressbar" style="width: 0%">0%</div>
      </div>
      <p id="uploadStatus" class="mt-2"></p>
    </div>

    <h4 class="text-secondary mt-4 mb-2">📂 Files in EFS:</h4>
    <div id="fileList">
      {% if files %}
        {% for f in files %}
          <div class="file-card">
            <div>
              <i class="bi bi-file-earmark file-icon"></i>
              <a href="/files/{{f}}" class="text-decoration-none text-dark">{{f}}</a>
            </div>
            <button class="btn btn-sm btn-outline-danger" onclick="confirmDelete('{{f}}')"><i class="bi bi-trash"></i> Delete</button>
          </div>
        {% endfor %}
      {% else %}
        <p class="text-center text-muted">No files uploaded yet.</p>
      {% endif %}
    </div>

    <div class="footer">
      <p>Powered by <b>Flask</b> + <b>Amazon EFS</b></p>
    </div>
  </div>

  <script>
    const uploadBtn = document.getElementById('uploadBtn');
    const fileInput = document.getElementById('fileInput');
    const progressBar = document.getElementById('progressBar');
    const progressDiv = document.querySelector('.progress');
    const uploadStatus = document.getElementById('uploadStatus');

    // Handle file upload with progress
    uploadBtn.addEventListener('click', async () => {
      const file = fileInput.files[0];
      if (!file) {
        alert('Please select a file first.');
        return;
      }

      const formData = new FormData();
      formData.append('file', file);
      progressDiv.style.display = 'block';
      uploadStatus.textContent = '';
      progressBar.style.width = '0%';
      progressBar.textContent = '0%';

      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload', true);

      xhr.upload.onprogress = (event) => {
        if (event.lengthComputable) {
          const percentComplete = Math.round((event.loaded / event.total) * 100);
          progressBar.style.width = percentComplete + '%';
          progressBar.textContent = percentComplete + '%';
        }
      };

      xhr.onload = () => {
        if (xhr.status === 200) {
          progressBar.classList.remove('bg-danger');
          progressBar.classList.add('bg-success');
          uploadStatus.innerHTML = '<span class="text-success fw-bold">✅ Upload complete!</span>';
          setTimeout(() => window.location.reload(), 1000);
        } else {
          progressBar.classList.add('bg-danger');
          uploadStatus.innerHTML = '<span class="text-danger fw-bold">❌ Upload failed.</span>';
        }
      };

      xhr.send(formData);
    });

    // Handle delete with confirmation
    function confirmDelete(filename) {
      if (confirm(`Are you sure you want to delete "${filename}"?`)) {
        fetch(`/delete/${filename}`, { method: 'DELETE' })
          .then(res => res.json())
          .then(data => {
            if (data.success) {
              alert('✅ File deleted successfully.');
              window.location.reload();
            } else {
              alert('❌ Failed to delete file.');
            }
          })
          .catch(() => alert('❌ Error deleting file.'));
      }
    }
  </script>
</body>
</html>
'''

# ---------------- FLASK ROUTES ----------------
@app.route('/')
def index():
    files = sorted(os.listdir(UPLOAD_FOLDER))
    return render_template_string(html, files=files)

@app.route('/upload', methods=['POST'])
def upload_file():
    """Handle file upload with AJAX and save to EFS."""
    file = request.files.get('file')
    if not file:
        return jsonify({'error': 'No file provided'}), 400
    filename = secure_filename(file.filename)
    file.save(os.path.join(UPLOAD_FOLDER, filename))
    return jsonify({'message': 'File uploaded successfully'}), 200

@app.route('/delete/<filename>', methods=['DELETE'])
def delete_file(filename):
    """Delete a file from EFS."""
    try:
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        if os.path.exists(file_path):
            os.remove(file_path)
            return jsonify({'success': True}), 200
        else:
            return jsonify({'success': False, 'error': 'File not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/files/<filename>')
def serve_file(filename):
    """Serve uploaded files from EFS."""
    return send_from_directory(UPLOAD_FOLDER, filename)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
`

# ansible
https://github.com/Manohar-1305/ansible_playbook_k8s-installation

# cost
https://github.com/Manohar-1305/aws_cost_projector

