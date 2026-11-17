<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>供应商门户 · 资质上传</title>
  <link rel="stylesheet" href="/assets/plugins/fontawesome-free/css/all.min.css">
  <link rel="stylesheet" href="/assets/dist/css/adminlte.min.css">
</head>
<body class="hold-transition sidebar-mini">
<div class="wrapper">
  <nav class="main-header navbar navbar-expand navbar-white navbar-light">
    <ul class="navbar-nav">
      <li class="nav-item"><a class="nav-link" data-widget="pushmenu" href="#" role="button"><i class="fas fa-bars"></i></a></li>
      <li class="nav-item d-none d-sm-inline-block"><a href="index.action" class="nav-link">门户首页</a></li>
    </ul>
  </nav>
  <aside class="main-sidebar sidebar-dark-primary elevation-4">
    <a href="index.action" class="brand-link"><img src="/assets/dist/img/AdminLTELogo.png" class="brand-image img-circle elevation-3" style="opacity:.8"><span class="brand-text font-weight-light">恒远供应商</span></a>
    <div class="sidebar">
      <nav class="mt-2"><ul class="nav nav-pills nav-sidebar flex-column" data-widget="treeview" role="menu">
        <li class="nav-item"><a href="index.action" class="nav-link"><i class="nav-icon fas fa-home"></i><p>门户首页</p></a></li>
        <li class="nav-item"><a href="upload.action" class="nav-link active"><i class="nav-icon fas fa-upload"></i><p>资质上传</p></a></li>
      </ul></nav>
    </div>
  </aside>
  <div class="content-wrapper">
    <div class="content-header"><div class="container-fluid"><div class="row mb-2"><div class="col-sm-6"><h1 class="m-0"><s:property value="message"/></h1></div><div class="col-sm-6"><ol class="breadcrumb float-sm-right"><li class="breadcrumb-item"><a href="index.action">门户首页</a></li><li class="breadcrumb-item active">资质上传</li></ol></div></div></div></div>
    <div class="content"><div class="container-fluid">
      <div class="card">
        <div class="card-header"><h3 class="card-title">上传供应商资质文件</h3></div>
        <div class="card-body">
          <form action="upload.action" method="post" enctype="multipart/form-data">
            <div class="form-group">
              <label>选择文件</label>
              <div class="input-group">
                <div class="custom-file">
                  <input type="file" name="upload" class="custom-file-input" id="uploadFile">
                  <label class="custom-file-label" for="uploadFile">点击选择文件…</label>
                </div>
              </div>
            </div>
            <button type="submit" class="btn btn-primary"><i class="fas fa-upload"></i> 上传</button>
          </form>
          <p class="text-muted mt-3 mb-0"><small>支持 PDF/JPG，单文件 ≤10MB。</small></p>
        </div>
      </div>
    </div></div>
  </div>
  <footer class="main-footer"><strong>Copyright &copy; 2023 恒远集团信息技术部.</strong></footer>
</div>
<script src="/assets/plugins/jquery/jquery.min.js"></script>
<script src="/assets/plugins/bootstrap/js/bootstrap.bundle.min.js"></script>
<script src="/assets/dist/js/adminlte.min.js"></script>
<script>
$(function () {
  $('#uploadFile').on('change', function () {
    var name = $(this).val().split('\\').pop();
    $(this).next('.custom-file-label').text(name || '点击选择文件…');
  });
});
</script>
</body>
</html>