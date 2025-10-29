FROM mysql:8.0

# 设置工作目录
WORKDIR /app

# 复制配置文件
COPY my.cnf /etc/mysql/conf.d/
COPY skip-name-resolve.cnf /etc/mysql/conf.d/

# 复制备份脚本
COPY mysql-backup/ /backup/
COPY media-backup/ /media-backup/

# 设置权限
RUN chmod +x /backup/backup.sh
RUN chmod +x /media-backup/entrypoint.sh

# 暴露端口
EXPOSE 3306

# 启动命令
CMD ["mysqld"]
