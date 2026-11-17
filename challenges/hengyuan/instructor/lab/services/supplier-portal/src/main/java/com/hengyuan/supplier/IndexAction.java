package com.hengyuan.supplier;

import com.opensymphony.xwork2.ActionSupport;

/** 供应商门户首页 action。S2-045 在 Struts filter 解析畸形 multipart Content-Type 时触发, 与 action 逻辑无关。 */
public class IndexAction extends ActionSupport {
    private static final long serialVersionUID = 1L;
    private String message;

    @Override
    public String execute() {
        message = "恒远集团供应商门户 (遗留系统 v1.0)";
        return SUCCESS;
    }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}