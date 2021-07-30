#!/bin/bash

read -p "please input github url : " URL

git init

git add .

git commit -m "update time $date" 

git remote add origin $URL

git push -u origin main