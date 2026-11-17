package com.hengyuan.supplier;

import com.opensymphony.xwork2.ActionSupport;

import java.io.File;

/** 遗留上传 action (jakarta multipart 解析器)。S2-045 触发点: 畸形 Content-Type 中的 OGNL。 */
public class UploadAction extends ActionSupport {
    private static final long serialVersionUID = 1L;
    private File upload;
    private String uploadContentType;
    private String uploadFileName;
    private String message;

    @Override
    public String execute() {
        message = "供应商资质上传接口 (遗留)";
        return SUCCESS;
    }

    public File getUpload() { return upload; }
    public void setUpload(File upload) { this.upload = upload; }
    public String getUploadContentType() { return uploadContentType; }
    public void setUploadContentType(String v) { this.uploadContentType = v; }
    public String getUploadFileName() { return uploadFileName; }
    public void setUploadFileName(String v) { this.uploadFileName = v; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}