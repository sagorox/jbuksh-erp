# Database Guide

## Live database
Live database runs in XAMPP MySQL:
C:\xampp\mysql\data

This folder is NOT tracked by Git.

## Tracked database files
This project tracks:
- full_dump_latest.sql
- backups/*.sql
- schema/*.sql
- seed/*.sql
- migrations/*.sql

## Refresh latest DB dump
Run:
backup_db.bat

## Typical workflow
1. Change DB from app / phpMyAdmin / backend
2. Run backup_db.bat
3. git status
4. git add .
5. git commit -m "Updated DB dump"
6. git push