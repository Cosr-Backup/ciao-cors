FROM denoland/deno:1.40.0

WORKDIR /app

# 复制依赖文件
COPY deno.json deno.lock ./

# 安装依赖
RUN deno cache --reload src/main.ts

# 复制源代码
COPY src/ ./src/

# 创建数据目录
RUN mkdir -p /app/data

# 设置权限
RUN chmod -R 755 /app

# 暴露端口
EXPOSE 8000

# 运行应用
CMD ["deno", "run", "--allow-net", "--allow-read", "--allow-write", "--allow-env", "src/main.ts"]