#!/bin/sh

#git pull
docker build  -t myvpn .
CID=$(docker run -d --privileged --net=host myvpn)
echo $CID
sleep 5
docker run -t -i -p 8080:8080 --volumes-from $CID myvpn serveconfig