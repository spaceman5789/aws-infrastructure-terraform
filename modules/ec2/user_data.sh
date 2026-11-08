#!/bin/bash
# Minimal web server so the ALB health check on / succeeds
dnf install -y nginx
systemctl enable --now nginx
