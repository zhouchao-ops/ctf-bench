ARG PYTHON_IMAGE=python:3.12-slim
FROM ${PYTHON_IMAGE}

WORKDIR /app
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 应用源码 (下一阶段实现: app/main.py, app/auth.py, app/routers/*)
COPY app/ ./app/
# 员工种子由 compose 绑定挂载 canonical seed/employees.json -> /app/seed/employees.json

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]